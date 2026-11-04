return {
	Name = "Seaweed",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.1,
	AverageKg = 0.3,
	MaxKg = 0.8,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local stem, holdfast = rgb(62, 83, 31), rgb(74, 65, 30)
		local colors = { rgb(58, 103, 39), rgb(77, 124, 43), rgb(47, 91, 36), rgb(93, 132, 48), rgb(64, 114, 42) }
		local root = Vector3.new(-0.46, -0.08, 0)
		b:ellipsoid("Holdfast", CFrame.new(root), Vector3.new(0.13, 0.1, 0.13), holdfast)
		-- Five tapered ribbons curl away from a shared stem, with raised midribs.
		for frond = 1, 5 do
			local spread = (frond - 3) * 0.12
			local length = 0.82 + (if frond % 2 == 0 then 0.1 else 0)
			local previousLeft, previousRight, previousCenter
			for segment = 0, 6 do
				local t = segment / 6
				local center = root
					+ Vector3.new(
						length * t,
						spread * t + math.sin(t * math.pi * 2 + frond) * 0.045 * t,
						(frond - 3) * 0.025 * t + math.sin(t * math.pi * 2.5 + frond) * 0.065 * t
					)
				local width = 0.009 + math.sin(t * math.pi) * 0.055
				local across = Vector3.new(0, width, math.sin(t * math.pi + frond) * width * 0.45)
				local left, right = center - across, center + across
				if previousCenter then
					for _, points in { { previousLeft, previousRight, right }, { previousLeft, right, left } } do
						local first, second = b:triangle(points[1], points[2], points[3], colors[frond])
						for _, part in { first, second } do
							part.Name = "SeaweedFrond"
						end
					end
					b:limb(previousCenter, center, 0.009, stem, "Midrib")
				end
				previousLeft, previousRight, previousCenter = left, right, center
			end
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.25, 0.4, 1))
	end,
}
