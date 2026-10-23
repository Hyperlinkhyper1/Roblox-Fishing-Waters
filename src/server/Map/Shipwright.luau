-- Mara is a locally built R6 rig dressed in genuine Roblox Marketplace items.
-- HumanoidDescription applies the catalog shirt, pants, hard hat and tool belt,
-- so those are the real catalog models instead of hand-sculpted lookalikes.
-- Classic faces are no longer sold in the Marketplace, so the head keeps the
-- engine's built-in smile texture. Building the rig locally keeps the shipwright
-- present even when an asset request is slow or unavailable.

local Shipwright = {}

local COSMETICS_VERSION = 3
local SKIN = Color3.fromRGB(216, 164, 119)

-- Verified Marketplace assets (all currently for sale):
--   Shirt  "Mechanic Coveralls +" (navy short-sleeved coverall top)
--   Pants  "Mechanic Coveralls -" (matching trousers and work boots)
--   Hat    "Hard Hat" (yellow construction helmet)
--   Waist  "Tool Belt" (hammer, wrenches and tape measure)
local COSMETICS = {
	Shirt = 6500613508,
	Pants = 6500616492,
	Hat = 9667880157,
	Waist = 12127743738,
}
Shipwright.COSMETICS = COSMETICS

local BODY_PARTS = {
	HumanoidRootPart = true,
	Torso = true,
	Head = true,
	["Right Arm"] = true,
	["Left Arm"] = true,
	["Right Leg"] = true,
	["Left Leg"] = true,
}

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

local function createDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.Name = "ShipwrightAppearance"
	description.Shirt = COSMETICS.Shirt
	description.Pants = COSMETICS.Pants
	description.HatAccessory = tostring(COSMETICS.Hat)
	description.WaistAccessory = tostring(COSMETICS.Waist)
	description.HeadColor = SKIN
	description.TorsoColor = SKIN
	description.LeftArmColor = SKIN
	description.RightArmColor = SKIN
	description.LeftLegColor = SKIN
	description.RightLegColor = SKIN
	return description
end

-- Classic faces are retired from the Marketplace, so restore the same built-in
-- smile the previous hand-built Mara used.
local function ensureFace(model: Model)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local face = head:FindFirstChild("face")
	if face and face:IsA("Decal") then
		return
	end
	local decal = Instance.new("Decal")
	decal.Name = "face"
	decal.Face = Enum.NormalId.Front
	decal.Texture = "rbxasset://textures/face.png"
	decal.Parent = head
end

-- Older baked maps carried the previous hand-modelled costume. Remove those
-- pieces before applying the catalog outfit, otherwise both hats would render.
local function stripLegacyDetails(model: Model)
	for _, item in model:GetDescendants() do
		if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") then
			item:Destroy()
		elseif item:IsA("BasePart") and not BODY_PARTS[item.Name] then
			item:Destroy()
		elseif item:IsA("Decal") and item.Name == "face" then
			item:Destroy()
		end
	end
end

-- Applies the Marketplace outfit to a fresh or previously baked shipwright.
-- Returns true once the description has been applied and remembered on the
-- model, so repeated world upgrades do not reload the avatar assets.
function Shipwright.ensureAppearance(model: Model): boolean
	if model:GetAttribute("CosmeticsVersion") == COSMETICS_VERSION then
		return true
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	-- Baked shipwrights predate the explicit rig type; keep descriptions on R6.
	humanoid.RigType = Enum.HumanoidRigType.R6

	stripLegacyDetails(model)

	local description = createDescription()
	local applied, reason = pcall(function()
		humanoid:ApplyDescriptionAsync(description)
	end)
	description:Destroy()
	-- Keep a readable face even if the catalog request failed.
	ensureFace(model)
	if not applied then
		warn("Shipwright Marketplace cosmetics failed to load: " .. tostring(reason))
		return false
	end

	-- Applying before the model is parented can silently skip the accessories.
	-- Report that as unfinished so the caller's post-parent retry runs.
	local hasShirt, hasPants, hasAccessory = false, false, false
	for _, item in model:GetDescendants() do
		if item:IsA("Shirt") then
			hasShirt = true
		elseif item:IsA("Pants") then
			hasPants = true
		elseif item:IsA("Accessory") then
			hasAccessory = true
		end
	end
	if not (hasShirt and hasPants and hasAccessory) then
		warn("Shipwright Marketplace cosmetics did not fully attach; retrying after parenting")
		return false
	end

	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.Massless = true
			item.Anchored = item.Name == "HumanoidRootPart"
			if item.Name == "HumanoidRootPart" then
				item.CanQuery = false
				item.CastShadow = false
			end
		end
	end

	model:SetAttribute("CosmeticsVersion", COSMETICS_VERSION)
	return true
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

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), SKIN)
	root.Transparency = 1
	root.CanQuery = false
	root.Anchored = true
	root.CastShadow = false
	local torso = part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), SKIN)
	local head = part("Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), SKIN)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.1, 1.1, 1.1)
	headMesh.Parent = head

	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), SKIN)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), SKIN)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), SKIN)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), SKIN)

	-- Standard R6 attachment points, copied from Roblox's own R6 character.
	-- Humanoid:ApplyDescription welds catalog accessories to the attachment that
	-- shares their name, so the hard hat and tool belt land in the right place.
	local function attach(bodyPart: BasePart, name: string, offset: Vector3)
		local point = Instance.new("Attachment")
		point.Name = name
		point.CFrame = CFrame.new(offset.X, offset.Y, offset.Z)
		point.Parent = bodyPart
	end
	attach(head, "FaceCenterAttachment", Vector3.new(0, 0, 0))
	attach(head, "FaceFrontAttachment", Vector3.new(0, 0, -0.6))
	attach(head, "HairAttachment", Vector3.new(0, 0.6, 0))
	attach(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	attach(torso, "BodyBackAttachment", Vector3.new(0, 0, 0.5))
	attach(torso, "BodyFrontAttachment", Vector3.new(0, 0, -0.5))
	attach(torso, "LeftCollarAttachment", Vector3.new(-1, 1, 0))
	attach(torso, "NeckAttachment", Vector3.new(0, 1, 0))
	attach(torso, "RightCollarAttachment", Vector3.new(1, 1, 0))
	attach(torso, "WaistBackAttachment", Vector3.new(0, -1, 0.5))
	attach(torso, "WaistCenterAttachment", Vector3.new(0, -1, 0))
	attach(torso, "WaistFrontAttachment", Vector3.new(0, -1, -0.5))
	attach(rightArm, "RightShoulderAttachment", Vector3.new(0, 1, 0))
	attach(leftArm, "LeftShoulderAttachment", Vector3.new(0, 1, 0))

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

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Mara · Shipwright"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.NameDisplayDistance = 28
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.PrimaryPart = root
	Shipwright.ensureAppearance(model)
	Shipwright.ensureInteraction(model)
	return model
end

return Shipwright
