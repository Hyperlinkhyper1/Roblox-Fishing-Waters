-- Smooth drydock refit lift. The server only sets the cradle and hull at each end
-- of the trip and publishes the timeline on the drydock (DrydockLaunch.travel):
-- LiftRest, LiftContact, LiftFrom, LiftTo, LiftSeconds, LiftStartedAt. Every client
-- moves both anchored models locally each render frame on the shared server clock,
-- so they rise together without replication steps, and the seated owner (welded to
-- the hull) rides along. When a trip ends the server's own end pose matches ours.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DOCK_TAG = "RefitDock"

local DrydockLift = {}
local started = false

local function smooth(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

local function hullOf(dock: Instance): Model?
	local userId = dock:GetAttribute("LiftingUserId")
	local boats = workspace:FindFirstChild("PlayerBoats")
	if type(userId) ~= "number" or not boats then
		return nil
	end
	for _, model in boats:GetChildren() do
		if
			model:IsA("Model")
			and model:GetAttribute("OwnerUserId") == userId
			and typeof(model:GetAttribute("HoistPivot")) == "CFrame"
		then
			return model
		end
	end
	return nil
end

function DrydockLift.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local cast = RaycastParams.new()
	cast.FilterType = Enum.RaycastFilterType.Include
	-- The trip each dock last finished drawing, so a resting lift is not rewritten.
	local finished: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

	RunService:BindToRenderStep("DrydockLift", Enum.RenderPriority.Camera.Value - 1, function()
		local now = workspace:GetServerTimeNow()
		for _, dock in CollectionService:GetTagged(DOCK_TAG) do
			local startedAt, seconds = dock:GetAttribute("LiftStartedAt"), dock:GetAttribute("LiftSeconds")
			local from, to = dock:GetAttribute("LiftFrom"), dock:GetAttribute("LiftTo")
			local rest, contact = dock:GetAttribute("LiftRest"), dock:GetAttribute("LiftContact")
			if
				type(startedAt) ~= "number"
				or type(seconds) ~= "number"
				or type(from) ~= "number"
				or type(to) ~= "number"
				or typeof(rest) ~= "CFrame"
				or type(contact) ~= "number"
				or finished[dock] == startedAt
			then
				continue
			end
			local alpha = if seconds > 0 then math.clamp((now - startedAt) / seconds, 0, 1) else 1
			local rise = from + (to - from) * smooth(alpha)
			local cradle = dock:FindFirstChild("LaunchCradle", true)
			if cradle and cradle:IsA("Model") then
				cradle:PivotTo(rest + Vector3.new(0, rise, 0))
			end
			local hull = hullOf(dock)
			if hull then
				local base = hull:GetAttribute("HoistPivot") :: CFrame
				local target = base + Vector3.new(0, math.max(0, rise - contact), 0)
				local delta = target.Position.Y - hull:GetPivot().Position.Y
				-- A seated character is welded to the hull and follows it; carry
				-- someone standing on deck so they neither sink in nor hop down.
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if humanoid and root and root:IsA("BasePart") and not humanoid.SeatPart and delta ~= 0 then
					cast.FilterDescendantsInstances = { hull }
					local below = humanoid.HipHeight + root.Size.Y / 2 + 1.5
					if workspace:Raycast(root.Position, Vector3.new(0, -below, 0), cast) then
						root.CFrame += Vector3.new(0, delta, 0)
					end
				end
				hull:PivotTo(target)
			end
			if alpha >= 1 then
				finished[dock] = startedAt
			end
		end
	end)
end

return DrydockLift
