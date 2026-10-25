-- Procedural overhead cast: the right arm cocks back while charging and whips
-- forward on release. The local angler swings at once; other anglers' swings
-- replay from the rod's replicated CastAt, so no extra remotes are needed.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CastAnimation = {}
-- Shoulder pitch in torso space: 0 hangs down, pi/2 holds the rod forward.
local REST, COCKED, FOLLOW = math.pi / 2, 2.9, 1.0
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
	intents[tool] = { mode = "Swing", at = os.clock(), from = from }
end

function CastAnimation.cancel(tool: Tool)
	intents[tool] = nil
end

local function shoulder(character: Model): Motor6D?
	for _, name in { "RightShoulder", "Right Shoulder" } do
		local joint = character:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			return joint
		end
	end
	return nil
end

function CastAnimation.start()
	if started then return end
	started = true
	local poses = {}
	RunService.PreSimulation:Connect(function(dt)
		local now, serverNow = os.clock(), workspace:GetServerTimeNow()
		local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character
		local seen = {}
		for _, tool in CollectionService:GetTagged("FishingRod") do
			local character = tool.Parent
			local humanoid = if character and character:IsA("Model") then character:FindFirstChildOfClass("Humanoid") else nil
			if not humanoid or humanoid.Health <= 0 then continue end
			local angle: number? = nil
			if character == localCharacter then
				local intent = intents[tool]
				if intent and intent.mode == "WindUp" then
					angle = windUpAngle(now - intent.at)
				elseif intent then
					angle = swingAngle(now - intent.at, intent.from)
					if not angle then intents[tool] = nil end
				end
			else
				local castAt = tool:GetAttribute("CastAt")
				local elapsed = if type(castAt) == "number" then serverNow - castAt else -1
				if elapsed >= 0 and elapsed < BACKSWING then
					angle = REST + (COCKED - REST) * smooth(elapsed / BACKSWING)
				elseif elapsed >= BACKSWING then
					angle = swingAngle(elapsed - BACKSWING, COCKED)
				end
			end
			local pose = poses[tool]
			if not angle and not pose then continue end
			if not pose or pose.character ~= character or not pose.joint:IsDescendantOf(character) then
				local joint = shoulder(character)
				if not joint then continue end
				pose = { character = character, joint = joint, weight = 0, angle = REST }
				poses[tool] = pose
			end
			seen[tool] = true
			pose.angle = angle or pose.angle
			pose.weight += ((if angle then 1 else 0) - pose.weight) * (1 - math.exp(-16 * math.min(dt, 0.1)))
			-- R6 shoulders use rotated joint bases; rotate in torso space.
			local rotation = pose.joint.C0.Rotation
			local target = rotation:Inverse() * CFrame.Angles(pose.angle, 0, 0) * rotation
			-- Transform already holds this frame's tool-hold animation, so the swing blends in and out of it.
			pose.joint.Transform = pose.joint.Transform:Lerp(target, pose.weight)
			if not angle and pose.weight < 0.01 then
				poses[tool] = nil
			end
		end
		for tool, pose in poses do
			if not seen[tool] then
				if pose.joint.Parent then pose.joint.Transform = CFrame.identity end
				poses[tool] = nil
				intents[tool] = nil
			end
		end
	end)
end

return CastAnimation
