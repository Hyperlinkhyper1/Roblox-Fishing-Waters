-- Procedural casting and two-handed reeling for R6 and R15. Other anglers use
-- the rod's replicated CastAt/CastPhase; no uploaded assets or extra remotes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CastAnimation = {}
-- Shoulder pitch in torso space: 0 hangs down, pi/2 holds the rod forward.
local REST, COCKED, FOLLOW = math.pi / 2, 2.9, 1.0
local HOLD_WEIGHT = 0.92
local BACKSWING, WHIP, SETTLE = 0.12, 0.16, 0.45
local started = false
local intents = {}

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function windUpAngle(elapsed: number): number
	return REST + (COCKED - REST) * (1 - math.exp(-elapsed * 7))
end

local function swingAngle(elapsed: number, from: number): number?
	if elapsed < WHIP then
		return from + (FOLLOW - from) * smooth(elapsed / WHIP)
	elseif elapsed < WHIP + SETTLE then
		local a = (elapsed - WHIP) / SETTLE
		return FOLLOW + (REST - FOLLOW) * (1 - (1 - a) ^ 2)
	end
	return nil
end

function CastAnimation.windUp(tool: Tool)
	intents[tool] = { mode = "WindUp", at = os.clock() }
end

function CastAnimation.swing(tool: Tool)
	local intent = intents[tool]
	local from = if intent and intent.mode == "WindUp" then windUpAngle(os.clock() - intent.at) else COCKED
	-- Quick taps still get a backswing instead of barely moving from the hold.
	local backswing = BACKSWING * math.clamp((COCKED - from) / (COCKED - REST), 0, 1)
	intents[tool] = { mode = "Swing", at = os.clock(), from = from, backswing = backswing }
end

function CastAnimation.setReeling(tool: Tool, active: boolean)
	if active then
		intents[tool] = { mode = "Reel", at = os.clock() }
	elseif intents[tool] and intents[tool].mode == "Reel" then
		intents[tool] = nil
	end
end

function CastAnimation.pull(tool: Tool, landed: boolean)
	local intent = intents[tool]
	if intent and intent.mode == "Reel" then
		intent.pullAt = os.clock()
		intent.pullStrength = if landed then 0.42 else -0.18
	end
end

function CastAnimation.cancel(tool: Tool)
	intents[tool] = nil
end

local function findJoint(character: Model, names: { string }): Motor6D?
	for _, name in names do
		local joint = character:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	return nil
end

local EXTRA_JOINTS = {
	leftShoulder = { "LeftShoulder", "Left Shoulder" },
	rightElbow = { "RightElbow" },
	leftElbow = { "LeftElbow" },
	rightWrist = { "RightWrist" },
	leftWrist = { "LeftWrist" },
}

local function restore(pose)
	if pose.joint.Parent then
		pose.joint.Transform = CFrame.identity
	end
	for _, entry in pose.extra do
		if entry.joint.Parent then
			entry.joint.Transform = CFrame.identity
		end
	end
end

local function inJointSpace(joint: Motor6D, target: CFrame): CFrame
	local rotation = joint.C0.Rotation
	return rotation:Inverse() * target * rotation
end

function CastAnimation.start()
	if started then
		return
	end
	started = true
	local poses = {}
	-- Clear our previous offsets before the Animator runs, including joints that
	-- the current animation does not key (otherwise a reel pose can accumulate).
	RunService.PreAnimation:Connect(function()
		for _, pose in poses do
			restore(pose)
		end
	end)
	RunService.PreSimulation:Connect(function(dt)
		local now, serverNow = os.clock(), workspace:GetServerTimeNow()
		local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character
		local seen = {}
		for _, tool in CollectionService:GetTagged("FishingRod") do
			local character = tool.Parent
			local humanoid = if character and character:IsA("Model")
				then character:FindFirstChildOfClass("Humanoid")
				else nil
			if not humanoid or humanoid.Health <= 0 or not character:IsDescendantOf(workspace) then
				continue
			end
			local angle: number? = nil
			local reeling, tug = false, 0
			local intent = intents[tool]
			if character == localCharacter then
				if intent and intent.mode == "WindUp" then
					angle = windUpAngle(now - intent.at)
				elseif intent and intent.mode == "Swing" then
					local elapsed = now - intent.at
					if elapsed < intent.backswing then
						angle = intent.from + (COCKED - intent.from) * smooth(elapsed / intent.backswing)
					else
						angle = swingAngle(elapsed - intent.backswing, COCKED)
					end
					if not angle then
						intents[tool] = nil
					end
				elseif intent and intent.mode == "Reel" then
					reeling = true
					local elapsed = if intent.pullAt then now - intent.pullAt else 1
					if elapsed < 0.38 then
						tug = math.sin(elapsed / 0.38 * math.pi) * intent.pullStrength
					end
				end
			else
				local castAt = tool:GetAttribute("CastAt")
				local elapsed = if type(castAt) == "number" then serverNow - castAt else -1
				if elapsed >= 0 and elapsed < BACKSWING then
					angle = REST + (COCKED - REST) * smooth(elapsed / BACKSWING)
				elseif elapsed >= BACKSWING then
					angle = swingAngle(elapsed - BACKSWING, COCKED)
				end
				reeling = tool:GetAttribute("CastPhase") == "Hooked"
			end
			local castAt = tool:GetAttribute("CastAt")
			local cycle = (if type(castAt) == "number" then serverNow - castAt else now) * math.pi * 3.6
			if reeling then
				angle = REST + 0.18 + math.sin(cycle * 0.5) * 0.08 + tug
			end
			local pose = poses[tool]
			if not pose or pose.character ~= character or not pose.joint:IsDescendantOf(character) then
				if pose then
					restore(pose)
				end
				local joint = findJoint(character, { "RightShoulder", "Right Shoulder" })
				if not joint then
					continue
				end
				pose = { character = character, joint = joint, weight = 0, angle = REST, extra = {}, nextBind = 0 }
				poses[tool] = pose
			end
			seen[tool] = true
			local blend = 1 - math.exp(-16 * math.min(dt, 0.1))
			-- R15 limbs can stream in separately from the shoulder.
			if now >= pose.nextBind then
				pose.nextBind = now + 0.5
				for key, names in EXTRA_JOINTS do
					local entry = pose.extra[key]
					if not entry or not entry.joint:IsDescendantOf(character) then
						local joint = findJoint(character, names)
						pose.extra[key] = if joint then { joint = joint, weight = 0, target = CFrame.identity } else nil
					end
				end
			end
			pose.angle = if angle then angle else pose.angle + (REST - pose.angle) * blend
			pose.weight += ((if angle then 1 else HOLD_WEIGHT) - pose.weight) * blend
			local target = inJointSpace(pose.joint, CFrame.Angles(pose.angle, 0, 0))
			-- Keep a small amount of the Animator's motion, but stop walking packs
			-- from swinging the rod arm sideways between casts.
			pose.joint.Transform = pose.joint.Transform:Lerp(target, pose.weight)
			local targets = {}
			if reeling then
				-- Brace the rod with the right hand and circle the left hand around
				-- the reel. R6 uses the shoulders; R15 also bends elbows and wrists.
				targets.leftShoulder = CFrame.Angles(1.05 + math.sin(cycle) * 0.12, -0.6, 0.45 + math.cos(cycle) * 0.1)
				targets.leftElbow = CFrame.Angles(0.95 + math.cos(cycle) * 0.25, 0, 0)
				targets.leftWrist = CFrame.Angles(math.sin(cycle) * 0.25, 0, math.cos(cycle) * 0.18)
				targets.rightElbow = CFrame.Angles(0.25 + tug * 0.5, 0, 0)
				targets.rightWrist = CFrame.Angles(-0.12, 0, 0)
			elseif angle then
				local wind = math.clamp((angle - FOLLOW) / (COCKED - FOLLOW), 0, 1)
				targets.rightElbow = CFrame.Angles(wind * 0.65, 0, 0)
				targets.rightWrist = CFrame.Angles(-wind * 0.3, 0, 0)
				targets.leftShoulder = CFrame.Angles(0.5 + wind * 0.35, -0.25, 0.25)
				targets.leftElbow = CFrame.Angles(0.65, 0, 0)
			end
			for key, entry in pose.extra do
				if not entry.joint:IsDescendantOf(character) then
					continue
				end
				local extraTarget = targets[key]
				entry.target = entry.target:Lerp(extraTarget or CFrame.identity, blend)
				entry.weight += ((if extraTarget then 1 else 0) - entry.weight) * blend
				if entry.weight > 0.001 then
					entry.joint.Transform = entry.joint.Transform:Lerp(inJointSpace(entry.joint, entry.target), entry.weight)
				end
			end
		end
		for tool, pose in poses do
			if not seen[tool] then
				restore(pose)
				poses[tool] = nil
				intents[tool] = nil
			end
		end
	end)
end

return CastAnimation
