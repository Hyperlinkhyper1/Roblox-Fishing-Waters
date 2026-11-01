return {
	Name = "Arrow Squid",
	Rarity = "Rare",
	RarityDenominator = 20,
	MinKg = 0.3,
	AverageKg = 1,
	MaxKg = 6,
	BaseValue = 60,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#.", "##" },
		Big = { "#..", "###" },
		Huge = { "#...", "####", "#..." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(176, 94, 84), side = rgb(206, 134, 120), belly = rgb(236, 206, 194) }
		b:layered("Mantle", Vector3.new(0.17, 0, 0), Vector3.new(0.6, 0.15, 0.15), colors)
		b:layered("MantleTip", Vector3.new(0.42, 0, 0), Vector3.new(0.2, 0.075, 0.075), colors)
		b:body("MantlePoint", Vector3.new(0.5, 0, 0), Vector3.new(0.09, 0.034, 0.034), colors.side)
		b:body("Head", Vector3.new(-0.15, 0, 0), Vector3.new(0.14, 0.11, 0.12), colors.side)
		b:ellipsoid("Collar", CFrame.new(-0.11, 0, 0), Vector3.new(0.06, 0.13, 0.135), colors.back)
		local finColor = rgb(214, 152, 136)
		-- Rhomboid fins wrapping the rear third of the mantle.
		for _, side in { 1, -1 } do
			b:fin({
				Vector3.new(0.53, 0, 0),
				Vector3.new(0.45, 0, side * 0.1),
				Vector3.new(0.38, 0, side * 0.135),
				Vector3.new(0.3, 0, side * 0.09),
				Vector3.new(0.25, 0, side * 0.03),
				Vector3.new(0.25, 0, 0),
			}, finColor, 0.12)
		end
		b:speckle(70, v2(-0.08, 0.5), v2(-0.07, 0.075), v2(0.007, 0.016), rgb(128, 52, 46))
		b:stroke({ v2(0.48, 0.02), v2(0.0, 0.07) }, 0.006, rgb(150, 70, 62))
		b:eye(-0.15, 0.008, 0.07, rgb(172, 192, 204))
		local armColor = rgb(212, 142, 128)
		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			local spread = Vector3.new(0, math.cos(angle), math.sin(angle))
			local root = Vector3.new(-0.2, 0, 0) + spread * 0.035
			local middle = Vector3.new(-0.34, -0.01, 0) + spread * 0.055
			local tip = Vector3.new(-0.47 + math.abs(math.sin(angle)) * 0.03, -0.03, 0) + spread * 0.045
			b:limb(root, middle, 0.028, armColor, "Arm")
			b:limb(middle, tip, 0.017, armColor, "Arm")
			for step = 1, 3 do
				local sucker = root:Lerp(middle, step / 4) - spread * 0.012
				b:ellipsoid("Sucker", CFrame.new(sucker), Vector3.one * 0.008, rgb(238, 210, 196))
			end
		end
		for _, side in { 1, -1 } do
			local root, middle = Vector3.new(-0.2, -0.01, side * 0.015), Vector3.new(-0.42, -0.05, side * 0.04)
			local club = Vector3.new(-0.62, -0.03, side * 0.05)
			b:limb(root, middle, 0.012, armColor, "Tentacle")
			b:limb(middle, club, 0.01, armColor, "Tentacle")
			b:ellipsoid(
				"TentacleClub",
				CFrame.lookAt(club, club + Vector3.xAxis),
				Vector3.new(0.022, 0.026, 0.07),
				armColor
			)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.1, 0.65, 1))
	end,
}
