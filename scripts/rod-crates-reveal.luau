-- Uses the shared rod recording primitives, then executes the production reveal.
local multiply = frameMeta.__mul
frameMeta.__mul = function(a, b)
	return if b.Position then multiply(a, b) else a.Position + transform(a, b)
end
function CFrame.lookAt(eye, target)
	local back = (eye - target).Unit
	local right = vector(0, 1, 0):Cross(back).Unit
	return CFrame.fromMatrix(eye, right, back:Cross(right), back)
end
function frameMethods:Lerp(other, alpha)
	return CFrame.fromMatrix(
		self.Position:Lerp(other.Position, alpha),
		other.RightVector,
		other.UpVector,
		other.ZVector
	)
end
local function typeof(value)
	return if type(value) == "table" and value.RightVector then "CFrame" else type(value)
end
Enum.PlayerActions.GetEnumItems = function()
	return { "CharacterForward", "CharacterBackward", "CharacterLeft", "CharacterRight", "CharacterJump" }
end
local nativeNew = Instance.new
Instance.new = function(class)
	local item = nativeNew(class)
	if class == "Model" then
		function item:GetPivot()
			return self.pivot or (self.PrimaryPart and self.PrimaryPart.CFrame) or CFrame.identity
		end
		function item:PivotTo(frame)
			self.pivot = frame
		end
		function item:ScaleTo(scale)
			self.scale = scale
		end
	elseif class == "Part" then
		item.LocalTransparencyModifier = 0
	end
	return item
end
collection.RemoveTag = function(_, item)
	tags[item] = nil
end
run.RenderStepped = signal()
local player = {}
local prompts = { Enabled = true }
local bound = {}
local actions = {
	BindActionAtPriority = function(_, name, callback)
		bound[name] = callback
	end,
	UnbindAction = function(_, name)
		bound[name] = nil
	end,
}
local services = {
	CollectionService = collection,
	ContextActionService = actions,
	Players = { LocalPlayer = player },
	ProximityPromptService = prompts,
	ReplicatedStorage = {},
	RunService = run,
}
game.GetService = function(_, name)
	return assert(services[name], name)
end
local rodFactory = (function()
	-- FISHING_ROD_SOURCE --
end)()
local Reveal = (function()
	-- REVEAL_SOURCE --
end)()
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local crate, stand, lid, root, humanoid, camera
local origin = CFrame.new(6700, 300, -6) * CFrame.Angles(0, math.pi / 2, 0)
local function setup()
	crate = Instance.new("Model")
	crate.Parent = workspace
	crate:SetAttribute("CrateFrame", origin)
	crate:SetAttribute("LidHinge", origin * CFrame.new(0, 2.4, 0.9))
	stand = Instance.new("Part")
	stand.Parent = crate
	lid = Instance.new("Model")
	lid.Name, lid.Parent = "RodCrateLid", crate
	lid:PivotTo(origin * CFrame.new(0, 2.5, 0))
	player.Character = Instance.new("Model")
	root = Instance.new("Part")
	root.Name, root.Parent, root.Position = "HumanoidRootPart", player.Character, origin * vector(0, 3, -4)
	humanoid = Instance.new("Humanoid")
	humanoid.Parent, humanoid.Health = player.Character, 100
	camera = {
		CameraType = "Custom",
		CameraSubject = humanoid,
		FieldOfView = 70,
		CFrame = CFrame.new(6700, 305, -15),
		Focus = origin,
		ViewportSize = { X = 390, Y = 844 },
	}
	workspace.CurrentCamera = camera
end
local function tick(seconds)
	for _ = 1, math.floor(seconds * 100 + 0.5) do
		run.RenderStepped:Fire(0.01)
	end
end
local function reward()
	return workspace:FindFirstChild("UnboxedRod")
end
for _, skin in { "UmbrellaRod", "BambooRod", "BoneRod", "LanternRod", "BaguetteRod", "NightRod", "MageStaff" } do
	setup()
	local announced, finished = 0, 0
	local before = camera.CFrame
	local stop = Reveal.play(stand, skin, function()
		announced += 1
	end, function()
		finished += 1
	end)
	check(stop ~= nil and camera.CameraType == "Scriptable" and not prompts.Enabled, "Reveal takes camera and prompts")
	check(root.LocalTransparencyModifier == 1 and next(bound) ~= nil, "Player cannot obstruct the shot or move")
	tick(0.4)
	check(not reward() and announced == 0, "Reward is hidden while the lid is closed")
	tick(0.85)
	check(lid:GetPivot().UpVector:Dot(origin.UpVector) < 0, "The lid swings open behind the crate")
	tick(0.1)
	local rising = reward()
	check(rising ~= nil and rising.scale < 0.3, "The actual rod starts small inside the crate")
	local low = origin:ToObjectSpace(rising:GetPivot()).Position.Y
	for _, part in rising:GetDescendants() do
		if part:IsA("BasePart") then
			check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery, "Preview is inert")
		end
	end
	local tool = rising.children[1]
	check(
		tool:GetAttribute("RodSkin") == skin and tags[tool] == nil and not tool.Enabled,
		"Saved skin is displayed without live rod listeners"
	)
	tick(1.1)
	check(
		rising.scale > 0.99 and origin:ToObjectSpace(rising:GetPivot()).Position.Y > low + 1,
		"Rod rises to full size"
	)
	check(announced == 1 and finished == 0, "Reward is named once after rising")
	tick(3.2)
	check(
		finished == 1 and not reward() and run.RenderStepped:Count() == 0,
		"Reveal cleans up after holding the reward"
	)
	check(camera.CameraType == "Custom" and camera.FieldOfView == 70 and camera.CFrame == before, "Camera is restored")
	check(
		prompts.Enabled and next(bound) == nil and root.LocalTransparencyModifier == 0,
		"Prompts, movement, and character are restored"
	)
	check((lid:GetPivot().Position - (origin * vector(0, 2.5, 0))).Magnitude < 1e-6, "Lid closes exactly")
	stop()
	check(finished == 1, "Cleanup is idempotent")
	crate:Destroy()
end
for _, reason in { "cancel", "death", "respawn", "streaming", "distance", "camera" } do
	setup()
	local finished = 0
	prompts.Enabled = false
	root.LocalTransparencyModifier = 0.4
	local stop = Reveal.play(stand, "BambooRod", function() end, function()
		finished += 1
	end)
	tick(1.5)
	if reason == "cancel" then
		stop()
	elseif reason == "death" then
		humanoid.Health = 0
	elseif reason == "respawn" then
		player.Character = nil
	elseif reason == "streaming" then
		crate.Parent = nil
	elseif reason == "distance" then
		root.Position = origin * vector(0, 0, 30)
	elseif reason == "camera" then
		workspace.CurrentCamera = {}
	end
	tick(0.1)
	check(finished == 1 and not reward() and run.RenderStepped:Count() == 0, reason .. " ends the animation")
	check(
		not prompts.Enabled and root.LocalTransparencyModifier == 0.4 and next(bound) == nil,
		reason .. " restores prior state"
	)
	stop()
	crate:Destroy()
end
setup()
check(Reveal.play(nil, "BambooRod", function() end, function() end) == nil, "Missing stand is safe")
root.Position = origin * vector(0, 0, 40)
check(
	Reveal.play(stand, "BambooRod", function() end, function() end) == nil,
	"Late saves cannot take the camera far from the stand"
)
setup()
lid.Name = "BobberCrateLid"
local bobberReward = Instance.new("Model")
local bobberRoot = Instance.new("Part")
bobberRoot.Parent, bobberReward.PrimaryPart = bobberReward, bobberRoot
local bobberAnnounced, bobberFinished = 0, 0
local stopBobber = Reveal.play(stand, "CrownedGoldBobber", function()
	bobberAnnounced += 1
end, function()
	bobberFinished += 1
end, function()
	return bobberReward
end)
check(stopBobber ~= nil, "Bobber lid supports the shared world reveal")
tick(2.5)
check(
	bobberReward.Parent == workspace and bobberReward.scale > 4.9 and bobberAnnounced == 1,
	"Bobber reward rises at a readable display size"
)
tick(3.1)
check(
	bobberFinished == 1 and bobberReward.Parent == nil and camera.CameraType == "Custom",
	"Bobber reveal restores play and cleans up"
)
print(`Rod and bobber case reveals: {checks} checks passed (recording mocks; no Studio rendering)`)
