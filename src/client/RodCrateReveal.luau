-- Local shop animation: every angler sees their own saved reward emerge from the stand.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local FishingRod = require(ReplicatedStorage.Shared.FishingRod)

local Reveal = {}
local ACTION = "RodCrateRevealMovement"

local function ease(value: number): number
	local alpha = math.clamp(value, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

function Reveal.play(stand: BasePart?, skinId: string, onReward: () -> (), onFinished: () -> ()): (() -> ())?
	local crate = stand and stand.Parent
	local lid = crate and crate:FindFirstChild("RodCrateLid")
	local origin = crate and crate:GetAttribute("CrateFrame")
	local hinge = crate and crate:GetAttribute("LidHinge")
	local camera = workspace.CurrentCamera
	if
		not crate
		or not lid
		or not lid:IsA("Model")
		or typeof(origin) ~= "CFrame"
		or typeof(hinge) ~= "CFrame"
		or not camera
	then
		return nil
	end

	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or not crate:IsDescendantOf(workspace)
		or (root.Position - origin.Position).Magnitude > 18
	then
		return nil
	end
	local closed = lid:GetPivot()
	local hingeOffset = hinge:ToObjectSpace(closed)
	local saved = {
		kind = camera.CameraType,
		subject = camera.CameraSubject,
		frame = camera.CFrame,
		focus = camera.Focus,
		fov = camera.FieldOfView,
		prompts = ProximityPromptService.Enabled,
	}
	local rod = FishingRod.build(skinId)
	CollectionService:RemoveTag(rod, "FishingRod")
	rod.Enabled = false
	local reward = Instance.new("Model")
	reward.Name = "UnboxedRod"
	rod.Parent = reward
	reward.PrimaryPart = rod:FindFirstChild("Handle") :: BasePart
	for _, part in reward:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		end
	end
	reward:ScaleTo(0.15)
	reward:PivotTo(origin * CFrame.new(0, 1.45, 0))
	-- Keep it out of Workspace until the lid has opened.
	local connection: RBXScriptConnection?
	local finished, announced = false, false
	local elapsed = 0
	local hidden = {}
	local function stop()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		reward:Destroy()
		if lid.Parent then
			lid:PivotTo(closed)
		end
		ContextActionService:UnbindAction(ACTION)
		ProximityPromptService.Enabled = saved.prompts
		for part, transparency in hidden do
			if part.Parent then
				part.LocalTransparencyModifier = transparency
			end
		end
		if workspace.CurrentCamera == camera then
			local currentCharacter = player.Character
			local humanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
			camera.CameraSubject = if saved.subject and saved.subject.Parent then saved.subject else humanoid
			camera.CFrame, camera.Focus = saved.frame, saved.focus
			camera.FieldOfView = saved.fov
			camera.CameraType = saved.kind
		end
		onFinished()
	end

	ContextActionService:BindActionAtPriority(ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, 3000, unpack(Enum.PlayerActions:GetEnumItems()))
	ProximityPromptService.Enabled = false
	-- The angler can stand directly between the camera and the crate.
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	connection = RunService.RenderStepped:Connect(function(dt)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			player.Character ~= character
			or not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
			or not crate:IsDescendantOf(workspace)
			or not lid.Parent
			or workspace.CurrentCamera ~= camera
			or (root.Position - origin.Position).Magnitude > 18
		then
			stop()
			return
		end
		elapsed += dt
		local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
		local eye = origin * Vector3.new(3.5, 5.6, -math.max(12, 5 / math.max(0.3, aspect)))
		local target = origin * Vector3.new(0, 4.6, 0)
		local shot = CFrame.lookAt(eye, target)
		local enter = ease(elapsed / 0.45)
		local leave = ease((elapsed - 5.1) / 0.4)
		camera.CFrame = saved.frame:Lerp(shot, enter):Lerp(saved.frame, leave)
		camera.Focus = CFrame.new(target)
		camera.FieldOfView = saved.fov + (48 - saved.fov) * enter * (1 - leave)

		local opening = ease((elapsed - 0.45) / 0.75)
		local closing = ease((elapsed - 4.65) / 0.45)
		lid:PivotTo(hinge * CFrame.Angles(math.rad(110) * opening * (1 - closing), 0, 0) * hingeOffset)
		if elapsed >= 1.25 and elapsed < 4.65 then
			local rise = ease((elapsed - 1.25) / 1.1)
			reward:ScaleTo(0.15 + 0.85 * rise)
			reward:PivotTo(
				origin * CFrame.new(0, 1.45 + 1.95 * rise, -0.12) * CFrame.Angles(0, (elapsed - 1.25) * 0.65, 0)
			)
			reward.Parent = workspace
		elseif elapsed >= 4.65 then
			reward.Parent = nil
		end
		if elapsed >= 2.35 and not announced then
			announced = true
			onReward()
		end
		if elapsed >= 5.5 then
			stop()
		end
	end)
	return stop
end

return Reveal
