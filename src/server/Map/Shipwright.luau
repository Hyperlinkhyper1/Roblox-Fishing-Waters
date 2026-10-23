-- A self-contained Roblox rig so the shipwright is available without avatar or asset requests.
local Shipwright = {}

local rgb = Color3.fromRGB
local COVERALLS = rgb(40, 98, 113)
local SLEEVE = rgb(50, 116, 126)
local SKIN = rgb(216, 164, 119)
local BOOTS = rgb(57, 47, 38)
local BELT = rgb(87, 65, 44)
local HARDHAT = rgb(237, 177, 50)
local METAL = rgb(177, 188, 186)

-- Also repair baked NPCs without rebuilding the workshop or launch equipment.
function Shipwright.ensureInteraction(model: Model): ProximityPrompt?
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local prompt = model:FindFirstChild("TalkToShipwrightPrompt", true)
	if prompt and not prompt:IsA("ProximityPrompt") then
		prompt:Destroy()
		prompt = nil
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TalkToShipwrightPrompt"
	end
	-- The invisible root is inside the torso, where camera occlusion can hide
	-- the prompt. Display it at the head; BoatService checks range, interior and
	-- the player's sightline on the server before opening or buying anything.
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Mara · Shipwright"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Enabled = true
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ClickablePrompt = true
	prompt.UIOffset = Vector2.new(0, -30)
	prompt.Parent = head
	return prompt
end

-- frame is at the soles of the boots. The rig looks along its local -Z axis.
function Shipwright.build(frame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Shipwright"
	model:SetAttribute("NpcName", "Mara")
	model:SetAttribute("Role", "Shipwright")

	local function part(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = frame * offset
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = model
		return p
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), COVERALLS)
	root.Transparency = 1
	root.CanQuery = false
	root.Anchored = true
	root.CastShadow = false
	local torso = part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), COVERALLS)
	local head = part("Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), SKIN)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.1, 1.1, 1.1)
	headMesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), SKIN)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), SKIN)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), COVERALLS)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), COVERALLS)

	-- Standard R6 joint names and positions keep all six body parts on one rig.
	local function motor(name: string, a: BasePart, b: BasePart, offset: CFrame)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0 = a
		joint.Part1 = b
		local jointFrame = frame * offset
		joint.C0 = a.CFrame:ToObjectSpace(jointFrame)
		joint.C1 = b.CFrame:ToObjectSpace(jointFrame)
		joint.Parent = a
	end
	motor("RootJoint", root, torso, CFrame.new(0, 3, 0))
	motor("Neck", torso, head, CFrame.new(0, 4, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 3.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 3.5, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, 2, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, 2, 0))

	local function detail(name: string, size: Vector3, offset: CFrame, color: Color3, body: BasePart): Part
		local p = part(name, size, offset, color)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	-- Rolled sleeves and a pocketed bib make her read as a working dockhand.
	for _, side in { -1, 1 } do
		local arm = if side == -1 then leftArm else rightArm
		local leg = if side == -1 then leftLeg else rightLeg
		detail("CoverallSleeve", Vector3.new(1.04, 1.05, 1.04), CFrame.new(side * 1.5, 3.49, 0), SLEEVE, arm)
		detail("RolledCuff", Vector3.new(1.08, 0.18, 1.08), CFrame.new(side * 1.5, 3.01, 0), COVERALLS, arm)
		detail("WorkBoot", Vector3.new(0.98, 0.58, 1.2), CFrame.new(side * 0.5, 0.29, -0.08), BOOTS, leg)
		detail("BootSole", Vector3.new(1, 0.12, 1.22), CFrame.new(side * 0.5, 0.06, -0.08), rgb(38, 37, 34), leg)
		detail("BibStrap", Vector3.new(0.22, 1.25, 0.07), CFrame.new(side * 0.64, 3.32, -0.54), SLEEVE, torso)
		detail("StrapBuckle", Vector3.new(0.25, 0.13, 0.1), CFrame.new(side * 0.64, 3.62, -0.59), METAL, torso)
	end
	detail("BibPocket", Vector3.new(0.78, 0.45, 0.12), CFrame.new(0, 3.13, -0.58), SLEEVE, torso)
	detail("PocketSeam", Vector3.new(0.75, 0.04, 0.04), CFrame.new(0, 3.34, -0.66), rgb(99, 155, 158), torso)
	detail("Toolbelt", Vector3.new(2.08, 0.28, 1.09), CFrame.new(0, 2.42, 0), BELT, torso)
	detail("BeltBuckle", Vector3.new(0.35, 0.26, 0.1), CFrame.new(0, 2.42, -0.6), METAL, torso)
	detail("ToolPouch", Vector3.new(0.47, 0.63, 0.28), CFrame.new(-0.73, 2.21, -0.61), BELT, torso)
	detail("HammerHandle", Vector3.new(0.12, 0.75, 0.12), CFrame.new(0.83, 2.38, -0.65), rgb(157, 113, 67), torso)
	detail("HammerHead", Vector3.new(0.46, 0.18, 0.22), CFrame.new(0.83, 2.77, -0.65), METAL, torso)

	-- A rounded yellow hardhat, rather than a plain colored head block.
	local helmet = detail("HardhatCrown", Vector3.new(2.12, 0.85, 1.65), CFrame.new(0, 5.07, 0), HARDHAT, head)
	helmet.Shape = Enum.PartType.Ball
	local brim = detail(
		"HardhatBrim",
		Vector3.new(0.13, 2.35, 1.85),
		CFrame.new(0, 4.97, -0.08) * CFrame.Angles(0, 0, math.pi / 2),
		HARDHAT,
		head
	)
	brim.Shape = Enum.PartType.Cylinder
	detail("HardhatRidge", Vector3.new(0.13, 0.12, 1.15), CFrame.new(0, 5.48, 0), rgb(249, 196, 67), head)

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Mara · Shipwright"
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.NameDisplayDistance = 28
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.PrimaryPart = root
	Shipwright.ensureInteraction(model)
	return model
end

return Shipwright
