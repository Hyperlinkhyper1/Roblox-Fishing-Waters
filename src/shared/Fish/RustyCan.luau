return {
	Name = "Rusty Can",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.05,
	AverageKg = 0.15,
	MaxKg = 0.35,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local steel, rim = rgb(122, 133, 130), rgb(154, 160, 149)
		local rust, darkRust = rgb(151, 82, 43), rgb(100, 58, 35)
		local function disc(name, center, height, diameter, color, tilt)
			local part = b:part(name, "Part", Vector3.new(height, diameter, diameter),
				CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2 + (tilt or 0)), color)
			part.Shape = Enum.PartType.Cylinder
			part.Material = Enum.Material.Metal
			return part
		end
		disc("CanBody", Vector3.new(0, -0.03, 0), 0.58, 0.43, steel)
		disc("BottomRim", Vector3.new(0, -0.326, 0), 0.027, 0.455, darkRust)
		for _, y in { -0.22, -0.12, 0.08, 0.18 } do
			disc("PressedRib", Vector3.new(0, y, 0), 0.016, 0.444, rim)
		end
		disc("TopRim", Vector3.new(0, 0.265, 0), 0.025, 0.455, rim)
		disc("OpenInterior", Vector3.new(0, 0.28, 0), 0.006, 0.405, rgb(42, 48, 40))
		-- A peeled-back lid leaves the dark opening visible from the display angle.
		disc("BentLid", Vector3.new(-0.16, 0.35, 0), 0.012, 0.39, steel, 0.7)
		for index = 0, 7 do
			local angle = index * math.pi * 2 / 8
			local y = -0.23 + (index % 3) * 0.18
			local patch = b:ellipsoid("Corrosion",
				CFrame.new(math.sin(angle) * 0.214, y, math.cos(angle) * 0.214)
					* CFrame.Angles(0, angle, index * 0.37),
				Vector3.new(0.11, 0.09 + (index % 2) * 0.05, 0.009),
				if index % 2 == 0 then rust else darkRust)
			patch.Material = Enum.Material.Metal
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.6, 0.5, 1))
	end,
}
