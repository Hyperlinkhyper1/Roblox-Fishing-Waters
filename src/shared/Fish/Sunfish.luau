return {
	Name = "Sunfish",
	Rarity = "Legendary",
	RarityDenominator = 150,
	MinKg = 20,
	AverageKg = 90,
	MaxKg = 600,
	BaseValue = 520,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Spring", "Summer" },
	Requires = { "Clear" },
	Shapes = {
		Normal = { ".##.", "####", ".##." },
		Big = { ".###.", "#####", ".###." },
		Huge = { ".####.", "######", "######", ".####." },
	},
	-- Ocean sunfish: a tall disc with long dorsal and anal fins and a frilled
	-- clavus where other fish have a tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(96, 104, 112), side = rgb(156, 164, 170), belly = rgb(222, 224, 222) }
		local fin = rgb(110, 118, 126)
		b:layered("Body", Vector3.new(0.05, 0, 0), Vector3.new(0.7, 0.62, 0.16), colors)
		b:layered("Head", Vector3.new(0.3, -0.02, 0), Vector3.new(0.26, 0.4, 0.14), colors)
		local top, bottom = b:top(-0.1), b:bottom(-0.1)
		b:fin({
			v2(-0.06, b:top(-0.06) - 0.01),
			v2(-0.18, top + 0.36),
			v2(-0.25, top + 0.3),
			v2(-0.24, b:top(-0.24) - 0.01),
		}, fin)
		b:fin({
			v2(-0.06, b:bottom(-0.06) + 0.01),
			v2(-0.18, bottom - 0.34),
			v2(-0.25, bottom - 0.28),
			v2(-0.24, b:bottom(-0.24) + 0.01),
		}, fin)
		local clavus = { v2(-0.24, 0) }
		for index = 0, 8 do
			local angle = math.rad(100 + index * 160 / 8)
			local wobble = if index % 2 == 0 then 1 else 0.86
			table.insert(clavus, v2(-0.27 + math.cos(angle) * 0.1 * wobble, math.sin(angle) * 0.28 * wobble))
		end
		b:fin(clavus, fin)
		b:pectoral(0.18, 0.02, 0.07, 0.05, fin)
		b:speckle(34, v2(-0.2, 0.3), v2(-0.25, 0.25), v2(0.02, 0.05), rgb(196, 200, 202))
		b:ellipsoid("Lips", CFrame.new(0.43, -0.02, 0), Vector3.new(0.04, 0.05, 0.05), colors.side)
		b:face(0.34, 0.06, 0.05, rgb(70, 76, 80), fin)
		b.model:SetAttribute("ViewDirection", Vector3.new(0.1, 0.1, 1))
	end,
}
