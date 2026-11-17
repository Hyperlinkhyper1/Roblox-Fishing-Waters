return {
	Name = "Glass Bottle",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.1,
	AverageKg = 0.35,
	MaxKg = 0.7,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "##" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local glass, edge = rgb(67, 115, 83), rgb(47, 83, 58)
		local function cylinder(name, x, length, diameter, color)
			local part = b:part(name, "Part", Vector3.new(length, diameter, diameter), CFrame.new(x, 0, 0), color, 0.12)
			part.Shape = Enum.PartType.Cylinder
			part.Material = Enum.Material.Glass
			return part
		end
		cylinder("BottleBody", -0.12, 0.5, 0.34, glass)
		cylinder("ThickBase", -0.37, 0.025, 0.345, edge)
		local shoulder = b:ellipsoid("Shoulder", CFrame.new(0.13, 0, 0), Vector3.new(0.29, 0.338, 0.338), glass, 0.12)
		shoulder.Material = Enum.Material.Glass
		cylinder("BottleNeck", 0.33, 0.28, 0.135, glass)
		cylinder("MouthRim", 0.477, 0.035, 0.165, edge)
		local opening = cylinder("OpenMouth", 0.497, 0.005, 0.112, rgb(26, 43, 31))
		opening.Transparency = 0
		-- A water-stained paper label remains on both sides of the empty bottle.
		for _, side in { -1, 1 } do
			b:part("OldLabel", "Part", Vector3.new(0.25, 0.17, 0.006),
				CFrame.new(-0.12, 0, side * 0.16), rgb(192, 183, 139))
			b:part("FadedLabelStripe", "Part", Vector3.new(0.17, 0.024, 0.007),
				CFrame.new(-0.12, 0.022, side * 0.164), rgb(115, 130, 100))
			b:part("LabelStain", "Part", Vector3.new(0.07, 0.047, 0.007),
				CFrame.new(-0.195, -0.052, side * 0.164) * CFrame.Angles(0, 0, -0.18), rgb(142, 137, 99))
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.7, 0.4, 1))
	end,
}
