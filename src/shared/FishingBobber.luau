-- One model for the hanging bobber, floating cast, crate reveal and collection.
local BobberSkins = require(script.Parent.BobberSkins)
local FishingBobber = {}

function FishingBobber.decorate(root: BasePart, skinId: string)
	local skin = BobberSkins.Skins[skinId]
	if not skin then
		return
	end
	root.Transparency = 1
	local function piece(name, class, size, offset, color, material)
		local part = Instance.new(class)
		part.Name, part.Size, part.CFrame = name, size, root.CFrame * offset
		part.Color, part.Material = Color3.fromRGB(unpack(color)), material or Enum.Material.SmoothPlastic
		part.Massless, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.CastShadow = false
		part.Parent = root
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, part, part
		return part
	end
	-- Stacked circular slices form the same two-tone float for every recolor.
	for index = 1, 12 do
		local y = -1 + (index - 0.5) / 6
		local diameter = 0.23 * math.sqrt(1 - y * y)
		local top = y > 0
		local ring = piece(
			if top then "BobberTop" else "BobberBottom",
			"Part",
			Vector3.new(0.31 / 12, diameter, diameter),
			CFrame.new(0, y * 0.155, 0) * CFrame.Angles(0, 0, math.pi / 2),
			if top then skin.Top else skin.Bottom,
			if top and skin.NeonTop then Enum.Material.Neon elseif skin.Crown then Enum.Material.Metal else nil
		)
		ring.Shape = Enum.PartType.Cylinder
	end
	local stem = piece(
		"BobberStem",
		"Part",
		Vector3.new(0.14, 0.035, 0.035),
		CFrame.new(0, 0.21, 0) * CFrame.Angles(0, 0, math.pi / 2),
		skin.Bottom
	)
	stem.Shape = Enum.PartType.Cylinder
	if skin.Crown then
		local gold = skin.Top
		local band = piece(
			"CrownBand",
			"Part",
			Vector3.new(0.045, 0.17, 0.17),
			CFrame.new(0, 0.175, 0) * CFrame.Angles(0, 0, math.pi / 2),
			gold,
			Enum.Material.Metal
		)
		band.Shape = Enum.PartType.Cylinder
		for index = 1, 5 do
			local angle = index * math.pi * 2 / 5
			piece(
				"CrownPoint",
				"WedgePart",
				Vector3.new(0.045, 0.085, 0.055),
				CFrame.new(math.sin(angle) * 0.065, 0.23, math.cos(angle) * 0.065) * CFrame.Angles(0, angle, 0),
				gold,
				Enum.Material.Metal
			)
		end
	end
end

function FishingBobber.build(skinId: string): Model
	local model = Instance.new("Model")
	model.Name = "DisplayBobber"
	local root = Instance.new("Part")
	root.Name, root.Size = "Bobber", Vector3.new(0.23, 0.31, 0.23)
	root.CFrame = CFrame.identity
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
	root.Parent, model.PrimaryPart = model, root
	FishingBobber.decorate(root, skinId)
	return model
end

return FishingBobber
