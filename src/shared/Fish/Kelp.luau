return {
	Name = "Kelp",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.1,
	AverageKg = 0.35,
	MaxKg = 1.5,
	BaseValue = 7,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	-- Giant kelp: a long stipe from a root-like holdfast, with broad, ruffled
	-- golden-brown blades on small gas bladders at staggered heights.
	Build = function(b, kit)
		local rgb, algaBlade = kit.rgb, kit.algaBlade
		local stipe, holdfast, bladder = rgb(92, 72, 34), rgb(70, 56, 30), rgb(150, 120, 52)
		local blades = { rgb(128, 104, 44), rgb(112, 92, 40), rgb(140, 114, 50), rgb(104, 86, 38) }
		local root = Vector3.new(-0.48, -0.06, 0)
		b:ellipsoid("Holdfast", CFrame.new(root), Vector3.new(0.1, 0.07, 0.11), holdfast)
		for index, angle in { 0.6, 2.2, 3.6, 5.0 } do
			local tip = root + Vector3.new(-0.02, -0.035, 0) + Vector3.new(0, 0, math.cos(angle) * 0.06)
			b:limb(root, tip + Vector3.new(0.01 * index, 0, math.sin(angle) * 0.01), 0.016, holdfast, "Holdfast")
		end
		local points = {}
		for step = 0, 6 do
			local t = step / 6
			table.insert(points, root + Vector3.new(0.9 * t, 0.05 * math.sin(t * math.pi * 1.3), 0.03 * math.sin(t * 4)))
		end
		for index = 1, #points - 1 do
			b:limb(points[index], points[index + 1], 0.016, stipe, "Midrib")
		end
		for index, spec in { { 2, 1 }, { 3, -1 }, { 4, 1 }, { 5, -1 }, { 6, 1 } } do
			local base, sign = points[spec[1]], spec[2]
			b:ellipsoid("Bladder", CFrame.new(base + Vector3.new(0.01, sign * 0.02, 0)), Vector3.new(0.035, 0.026, 0.026), bladder)
			local length = 0.42 - index * 0.03
			algaBlade(b, base + Vector3.new(0.02, sign * 0.03, 0), Vector3.new(0.75, sign * 0.55, 0.1 * sign), length, function(t)
				return 0.012 + 0.045 * math.sin(math.min(t * 1.4, 1) * math.pi / 2) * (if t > 0.8 then 1 - (t - 0.8) * 2.5 else 1)
			end, blades[(index - 1) % #blades + 1], 0.12, index)
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.25, 0.4, 1))
	end,
}
