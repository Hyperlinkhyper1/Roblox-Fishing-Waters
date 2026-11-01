return {
	Name = "Sea Lettuce",
	Rarity = "Uncommon",
	RarityDenominator = 6,
	MinKg = 0.05,
	AverageKg = 0.2,
	MaxKg = 0.9,
	BaseValue = 12,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	-- Sea lettuce (Ulva): a low, bushy tuft of thin, bright green sheets with
	-- crinkled margins and rounded tips. No midribs.
	Build = function(b, kit)
		local rgb, algaBlade = kit.rgb, kit.algaBlade
		local greens = { rgb(108, 181, 67), rgb(124, 196, 76), rgb(96, 168, 60), rgb(136, 204, 88) }
		local root = Vector3.new(-0.3, -0.12, 0)
		b:ellipsoid("Holdfast", CFrame.new(root), Vector3.new(0.05, 0.035, 0.05), rgb(78, 110, 52))
		local sheets = 7
		for index = 1, sheets do
			local spread = (index - (sheets + 1) / 2) / sheets
			local heading = Vector3.new(0.8 - math.abs(spread) * 0.3, 0.14 + spread * 0.8, math.sin(index * 2.1) * 0.7)
			local length = 0.4 + math.sin(index * 1.7) * 0.07
			local width = 0.075 + math.cos(index * 1.3) * 0.018
			algaBlade(b, root, heading, length, function(t)
				return 0.01 + width * math.sqrt(math.max(0, math.sin(math.min(t * 1.15, 1) * math.pi * 0.5 + (if t > 0.6 then (t - 0.6) * 3.9 else 0))))
			end, greens[(index - 1) % #greens + 1], 0.2, index * 1.3)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.25, 0.4, 1))
	end,
}
