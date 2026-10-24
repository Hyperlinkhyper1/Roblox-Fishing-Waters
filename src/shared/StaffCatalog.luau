-- One permanent hire per role; prices are charged by the server once.
local Staff = {
	Order = { "Seller", "Porter" },
	Roles = {
		Seller = {
			Name = "Seller",
			Price = 250,
			Description = "Serves customers at your register and collects payment automatically.",
		},
		Porter = {
			Name = "Porter",
			Price = 400,
			Description = "Carries fish from your boat to the freezer, one at a time. Park at your home dock to unload.",
		},
	},
}

-- Local uniforms need no Marketplace requests and look the same in the hiring
-- preview and the shop. Body colours also give the underlying R15 rig a skin.
local OUTFITS = {
	Seller = {
		Skin = Color3.fromRGB(224, 173, 132),
		Shirt = Color3.fromRGB(242, 232, 209),
		Pants = Color3.fromRGB(53, 65, 69),
		Boots = Color3.fromRGB(77, 53, 39),
		Uniform = Color3.fromRGB(36, 112, 107),
		Trim = Color3.fromRGB(225, 189, 110),
	},
	Porter = {
		Skin = Color3.fromRGB(157, 105, 74),
		Shirt = Color3.fromRGB(202, 140, 65),
		Pants = Color3.fromRGB(44, 64, 85),
		Boots = Color3.fromRGB(65, 46, 34),
		Uniform = Color3.fromRGB(39, 66, 84),
		Trim = Color3.fromRGB(239, 204, 125),
	},
}

function Staff.description(role: string): HumanoidDescription
	assert(Staff.Roles[role], "Unknown staff role")
	local outfit = OUTFITS[role]
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = outfit.Skin
	description.TorsoColor = outfit.Shirt
	description.LeftArmColor = outfit.Skin
	description.RightArmColor = outfit.Skin
	description.LeftLegColor = outfit.Pants
	description.RightLegColor = outfit.Pants
	return description
end

function Staff.applyAppearance(model: Model, role: string)
	assert(Staff.Roles[role], "Unknown staff role")
	local outfit = OUTFITS[role]
	local previous = model:FindFirstChild("StaffUniform")
	if previous then
		previous:Destroy()
	end
	local uniform = Instance.new("Folder")
	uniform.Name, uniform.Parent = "StaffUniform", model
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			local name = item.Name
			item.Color = if name == "Head" or string.find(name, "Hand") or string.find(name, "LowerArm") then outfit.Skin
				elseif string.find(name, "Foot") then outfit.Boots
				elseif string.find(name, "Leg") then outfit.Pants
				else outfit.Shirt
		end
	end

	-- Sized in body-part coordinates so details follow the R15 joints, including
	-- the waist while walking. Nothing adds collision, mass or an anchored part.
	local function detail(bodyName: string, name: string, size: Vector3, offset: Vector3, color: Color3)
		local body = model:FindFirstChild(bodyName)
		if not body or not body:IsA("BasePart") then
			return
		end
		local part = Instance.new("Part")
		part.Name = name
		part.Size = body.Size * size
		part.CFrame = body.CFrame * CFrame.new(body.Size * offset)
		part.Color, part.Material = color, Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Anchored, part.Massless = false, true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Parent = uniform
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = body, part, part
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local face = head:FindFirstChild("face")
		if not face then
			face = Instance.new("Decal")
			face.Name = "face"
			face.Face = Enum.NormalId.Front
			face.Texture = "rbxasset://textures/face.png"
			face.Parent = head
		end
	end

	if role == "Seller" then
		detail("UpperTorso", "ApronBib", Vector3.new(0.66, 0.82, 0.07), Vector3.new(0, -0.09, -0.52), outfit.Uniform)
		detail("LowerTorso", "ApronSkirt", Vector3.new(0.94, 1.06, 0.08), Vector3.new(0, 0, -0.53), outfit.Uniform)
		for _, side in { -1, 1 } do
			detail("UpperTorso", "ApronStrap", Vector3.new(0.09, 1.02, 0.08), Vector3.new(side * 0.24, 0, -0.54), outfit.Uniform)
		end
		detail("LowerTorso", "ApronPocket", Vector3.new(0.42, 0.32, 0.06), Vector3.new(0, -0.04, -0.60), outfit.Shirt)
		detail("UpperTorso", "NameBadge", Vector3.new(0.18, 0.12, 0.06), Vector3.new(-0.17, 0.13, -0.60), outfit.Trim)
		detail("Head", "ShopCap", Vector3.new(1.03, 0.29, 1.04), Vector3.new(0, 0.41, 0), outfit.Shirt)
		detail("Head", "CapBand", Vector3.new(1.05, 0.08, 1.06), Vector3.new(0, 0.30, 0), outfit.Uniform)
		detail("Head", "CapBrim", Vector3.new(1.06, 0.06, 0.50), Vector3.new(0, 0.29, -0.63), outfit.Uniform)
	else
		for _, side in { -1, 1 } do
			detail("UpperTorso", "WorkVest", Vector3.new(0.40, 1.02, 0.08), Vector3.new(side * 0.28, 0, -0.53), outfit.Uniform)
			detail("UpperTorso", "VestStripe", Vector3.new(0.40, 0.09, 0.06), Vector3.new(side * 0.28, -0.04, -0.60), outfit.Trim)
		end
		detail("UpperTorso", "VestBack", Vector3.new(1.02, 1.02, 0.08), Vector3.new(0, 0, 0.53), outfit.Uniform)
		detail("UpperTorso", "BackStripe", Vector3.new(1.02, 0.09, 0.06), Vector3.new(0, -0.04, 0.60), outfit.Trim)
		detail("LowerTorso", "WorkBelt", Vector3.new(1.03, 0.19, 1.04), Vector3.new(0, 0.20, 0), outfit.Boots)
		detail("LowerTorso", "BeltBuckle", Vector3.new(0.15, 0.17, 0.08), Vector3.new(0, 0.20, -0.56), outfit.Trim)
		detail("Head", "DockCap", Vector3.new(1.04, 0.34, 1.05), Vector3.new(0, 0.43, 0), outfit.Uniform)
		detail("Head", "DockCapCuff", Vector3.new(1.07, 0.12, 1.08), Vector3.new(0, 0.30, 0), outfit.Trim)
	end
end

return Staff
