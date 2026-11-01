return {
	Name = "Orange Sea Cucumber",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.1,
	AverageKg = 0.5,
	MaxKg = 2,
	BaseValue = 140,
	Fight = 0,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- Orange-footed sea cucumber: a plump, leathery orange-brown body with rows of
	-- tube feet along five ridges and a crown of bushy, branching orange tentacles.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(150, 72, 30), side = rgb(196, 102, 44), belly = rgb(230, 156, 96) }
		local tentacle, foot = rgb(240, 124, 40), rgb(246, 176, 110)
		b:layered("Body", Vector3.new(-0.04, 0, 0), Vector3.new(0.78, 0.24, 0.25), colors)
		b:layered("Front", Vector3.new(0.3, 0.005, 0), Vector3.new(0.18, 0.19, 0.2), colors)
		b:layered("Rear", Vector3.new(-0.38, -0.005, 0), Vector3.new(0.16, 0.16, 0.17), colors)
		-- Rows of tube feet along the body ridges.
		for _, row in { { 0.06, 1 }, { 0.06, -1 }, { -0.06, 1 }, { -0.06, -1 } } do
			for x = -0.36, 0.3, 0.05 do
				local position, normal = b:surface(x, row[1], row[2])
				if position and normal then
					b:limb(position - normal * 0.004, position + normal * 0.018, 0.016, foot, "Spine")
				end
			end
		end
		for x = -0.36, 0.3, 0.05 do
			local bottom = b:bottom(x)
			b:ellipsoid("TubeFoot", CFrame.new(x, bottom + 0.01, 0), Vector3.new(0.02, 0.022, 0.02), foot)
		end
		b:ellipsoid("Mouth", CFrame.new(0.39, 0.01, 0), Vector3.new(0.04, 0.09, 0.09), colors.back)
		for index = 0, 9 do
			local angle = index / 10 * math.pi * 2
			local spread = Vector3.new(0, math.cos(angle), math.sin(angle))
			local root = Vector3.new(0.39, 0.01, 0) + spread * 0.04
			local middle = Vector3.new(0.47, 0.01, 0) + spread * 0.08
			b:limb(root, middle, 0.016, tentacle, "Filament")
			-- Each tentacle branches into a little bush at its end.
			for branch = -1, 1 do
				local twist = Vector3.new(0, -math.sin(angle), math.cos(angle)) * branch * 0.025
				b:limb(middle, middle + spread * 0.04 + Vector3.new(0.035, 0, 0) + twist, 0.01, tentacle, "Filament")
			end
		end
	end,
}
