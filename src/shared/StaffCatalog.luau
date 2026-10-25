-- One permanent hire per role; prices are charged by the server once.
local Staff = {
	Order = { "Seller", "Porter", "Fisherman" },
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
		-- Requires names the Paths stage that unlocks hiring.
		Fisherman = {
			Name = "Fisherman",
			Price = 6000,
			Requires = "Company",
			Description = "Takes the boat you assign onto the water and fishes on his own. "
				.. "He moors beside your dock when the hold is full; your porter unloads the catch.",
		},
	},
}

-- Fixed Marketplace uniforms keep each job recognizable. Account avatars can
-- change independently of the game and bring unrelated logos or body packages.
-- Asset IDs are catalog items, not clothing-template image IDs.
local OUTFITS = {
	Seller = {
		Shirt = 382578523, -- Apron: white shirt with a dark bib apron
		Pants = 129459077, -- Black Slacks, including black shoes
		Hair = "376548738", -- Brown Charmer Hair
		Hat = "",
		Skin = Color3.fromRGB(224, 173, 132),
	},
	Porter = {
		Shirt = 6500613508, -- Mechanic Coveralls +
		Pants = 6500616492, -- Mechanic Coveralls -, matching navy trousers/boots
		Hair = "",
		Hat = "110050567314495", -- Plain Navy Beanie
		Skin = Color3.fromRGB(157, 105, 74),
	},
	Fisherman = {
		Shirt = 6500613508, -- Mechanic Coveralls +, matching the dock crew
		Pants = 129459077, -- Black Slacks, including black shoes
		Hair = "",
		Hat = "110050567314495", -- Plain Navy Beanie
		Skin = Color3.fromRGB(198, 140, 104),
	},
}

function Staff.description(role: string): HumanoidDescription
	assert(Staff.Roles[role], "Unknown staff role")
	local outfit = OUTFITS[role]
	local description = Instance.new("HumanoidDescription")
	description.Shirt, description.Pants = outfit.Shirt, outfit.Pants
	description.HairAccessory, description.HatAccessory = outfit.Hair, outfit.Hat
	description.HeadColor, description.TorsoColor = outfit.Skin, outfit.Skin
	description.LeftArmColor, description.RightArmColor = outfit.Skin, outfit.Skin
	description.LeftLegColor, description.RightLegColor = outfit.Skin, outfit.Skin
	-- Standard R15 joints with classic proportions for walking and carrying fish.
	description.BodyTypeScale, description.ProportionScale = 0, 0
	description.HeightScale, description.WidthScale, description.DepthScale = 1, 1, 1
	description.HeadScale = 1
	return description
end

-- Use the engine's smile instead of a retired Marketplace face or a face mask.
function Staff.finishModel(model: Model)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local face = head:FindFirstChild("face")
	if not face then
		face = Instance.new("Decal")
		face.Name, face.Parent = "face", head
	end
	if face:IsA("Decal") then
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
	end
end

return Staff
