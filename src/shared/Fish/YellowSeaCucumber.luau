return {
	Name = "Yellow Sea Cucumber",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.1,
	AverageKg = 0.4,
	MaxKg = 1.5,
	BaseValue = 50,
	Fight = 0,
	Pools = { "OpenSea" },
	Seasons = { "Autumn", "Winter" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "####" },
	},
	-- A soft yellow sausage studded with papillae, tube feet underneath and a
	-- ring of feeding tentacles at the front. No eyes.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(208, 160, 36), side = rgb(234, 196, 64), belly = rgb(244, 222, 140) }
		b:layered("Body", Vector3.new(0, 0, 0), Vector3.new(0.88, 0.2, 0.22), colors)
		b:layered("Front", Vector3.new(0.38, 0, 0), Vector3.new(0.18, 0.16, 0.17), colors)
		b:layered("Rear", Vector3.new(-0.38, 0, 0), Vector3.new(0.16, 0.14, 0.15), colors)
		for _ = 1, 46 do
			local x, y = b.random(-0.4, 0.4), b.random(-0.02, 0.09)
			local side = if b.random(0, 1) > 0.5 then 1 else -1
			local position, normal = b:surface(x, y, side)
			if position and normal then
				b:limb(position - normal * 0.006, position + normal * b.random(0.02, 0.04), 0.016, rgb(246, 210, 90), "Spine")
			end
		end
		for x = -0.36, 0.36, 0.045 do
			for _, z in { -0.05, 0.05 } do
				b:ellipsoid("TubeFoot", CFrame.new(x, b:bottom(x) + 0.004, z), Vector3.new(0.018, 0.02, 0.018), rgb(250, 236, 180))
			end
		end
		for index = 0, 9 do
			local angle = index / 10 * math.pi * 2
			local spread = Vector3.new(0, math.cos(angle), math.sin(angle))
			local root = Vector3.new(0.46, 0, 0) + spread * 0.04
			local tip = Vector3.new(0.54, 0, 0) + spread * 0.08
			b:limb(root, tip, 0.012, rgb(250, 226, 130), "Filament")
		end
	end,
}
