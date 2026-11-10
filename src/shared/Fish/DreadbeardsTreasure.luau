-- The one in a million: Dreadbeard's lost compass rose. Rod only, never netted,
-- and worth nothing at market because the only thing it buys cannot be sold.
return {
	Name = "Dreadbeard's Treasure",
	Rarity = "Secret",
	RarityDenominator = 1000000,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 0,
	Fight = 0,
	DropOnly = true,
	Secret = true,
	Shapes = {
		Normal = { "#" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		local gold = rgb(232, 181, 66)
		local bright = rgb(255, 226, 140)
		local dark = rgb(142, 96, 26)
		local shadow = rgb(86, 56, 14)
		local face = rgb(247, 205, 102)

		-- Cylinders run along local X; turn them to face the medallion's Z axis.
		local function disc(name, z, diameter, width, color)
			local part = b:part(
				name,
				"Part",
				Vector3.new(width, diameter, diameter),
				CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
				color
			)
			part.Shape = Enum.PartType.Cylinder
			return part
		end

		-- A heavy bevelled rim around a raised golden face.
		disc("Rim", 0, 0.8, 0.1, dark)
		disc("RimEdge", 0.025, 0.75, 0.09, gold)
		disc("Face", 0.06, 0.64, 0.08, face)
		disc("FaceInner", 0.095, 0.58, 0.04, bright)

		-- Eight compass points, each half bright and half shadowed, so the rose
		-- reads as cut metal rather than a flat decal.
		local long, short, halfWidth = 0.31, 0.2, 0.055
		for index = 0, 7 do
			local angle = index * math.pi / 4
			local dir = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local across = Vector3.new(-dir.Y, dir.X, 0)
			local reach = if index % 2 == 0 then long else short
			local tip = dir * reach + Vector3.new(0, 0, 0.125)
			local left = across * halfWidth + Vector3.new(0, 0, 0.125)
			local right = -across * halfWidth + Vector3.new(0, 0, 0.125)
			local notch = dir * 0.035 + Vector3.new(0, 0, 0.125)
			b:triangle(tip, notch, left, if index % 2 == 0 then bright else gold)
			b:triangle(tip, right, notch, if index % 2 == 0 then gold else dark)
			b:ellipsoid("PointStud", CFrame.new(dir * (reach + 0.012) + Vector3.new(0, 0, 0.126)), Vector3.one * 0.022, shadow)
		end

		-- The letter D: a straight spine joined to a half-round bowl.
		local spineX, radius, z = -0.085, 0.132, 0.138
		b:part("DSpine", "Part", Vector3.new(0.034, radius * 2, 0.022), CFrame.new(spineX, 0, z), shadow)
		local previous = Vector3.new(spineX, -radius, z)
		for step = 1, 9 do
			local theta = -math.pi / 2 + math.pi * step / 9
			local point = Vector3.new(spineX + math.cos(theta) * radius, math.sin(theta) * radius, z)
			b:limb(previous, point, 0.034, shadow, "DBowl")
			previous = point
		end

		-- A tiny gem above the rose gives the piece its pirate-loot glint.
		b:ellipsoid("Gem", CFrame.new(0, 0.32, 0.14), Vector3.new(0.05, 0.06, 0.03), rgb(190, 38, 52))
		b:ellipsoid("GemGlint", CFrame.new(-0.012, 0.335, 0.155), Vector3.one * 0.014, rgb(255, 226, 220))
		b.model:SetAttribute("ViewDirection", Vector3.new(0, 0.1, 1))
	end,
}
