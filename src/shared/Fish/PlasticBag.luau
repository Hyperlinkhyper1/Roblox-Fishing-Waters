return {
	Name = "Plastic Bag",
	Rarity = "Junk",
	RarityDenominator = 50,
	MinKg = 0.02,
	AverageKg = 0.08,
	MaxKg = 0.2,
	BaseValue = 1,
	Fight = 0,
	Shapes = {
		Normal = { "##", "##" },
	},
	Build = function(b, kit)
		local plastic, fold, seam = kit.rgb(219, 220, 201), kit.rgb(190, 195, 177), kit.rgb(165, 176, 156)
		local outline = {
			Vector3.new(-0.32, -0.39, 0),
			Vector3.new(0.23, -0.42, 0),
			Vector3.new(0.35, -0.17, 0),
			Vector3.new(0.28, 0.17, 0),
			Vector3.new(-0.26, 0.17, 0),
			Vector3.new(-0.35, -0.12, 0),
		}
		local function panel(a, c, d, color)
			local first, second = b:triangle(a, c, d, color)
			first.Name, second.Name = "CrumpledPlastic", "CrumpledPlastic"
		end
		-- Shallow folded panels keep the discarded bag flattened and uneven.
		for side = -1, 1, 2 do
			local center = Vector3.new(0.025, -0.11, side * 0.13)
			for index, point in outline do
				local nextPoint = outline[index % #outline + 1]
				panel(center, point, nextPoint, if index % 3 == 0 then fold else plastic)
			end
			b:limb(Vector3.new(-0.27, -0.35, side * 0.025), Vector3.new(-0.05, -0.14, side * 0.12), 0.008, seam, "Fold")
			b:limb(Vector3.new(0.25, -0.3, side * 0.035), Vector3.new(0.1, 0.02, side * 0.1), 0.006, fold, "Fold")
		end
		-- Two open strap loops rise from the shoulders of the bag.
		for _, side in { -1, 1 } do
			local x = side * 0.21
			local previous = Vector3.new(x - 0.065, 0.14, 0)
			for segment = 1, 8 do
				local angle = math.pi - segment * math.pi / 8
				local point = Vector3.new(x + math.cos(angle) * 0.065, 0.14 + math.sin(angle) * 0.29, 0)
				b:limb(previous, point, 0.032, plastic, "BagHandle")
				previous = point
			end
		end
		b:limb(Vector3.new(-0.31, -0.385, 0), Vector3.new(0.23, -0.415, 0), 0.012, seam, "BottomSeam")
		b.model:SetAttribute("ViewDirection", Vector3.new(0.25, 0.25, 1))
	end,
}
