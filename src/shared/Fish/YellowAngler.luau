return {
	Name = "Yellow Angler",
	Rarity = "Legendary",
	RarityDenominator = 90,
	MinKg = 2,
	AverageKg = 8,
	MaxKg = 50,
	BaseValue = 1200,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Autumn" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####" },
		Huge = { "#####", "#####", ".###." },
	},
	-- Fictional golden anglerfish: a huge round head with a gaping, fanged mouth,
	-- a short tapering tail and a glowing lure dangling over the jaws.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(200, 150, 26), side = rgb(238, 198, 58), belly = rgb(248, 228, 146) }
		local fin, tooth = rgb(214, 160, 40), rgb(250, 246, 226)
		b:layered("Body", Vector3.new(0.06, 0, 0), Vector3.new(0.62, 0.5, 0.46), colors)
		b:layered("TailBody", Vector3.new(-0.26, -0.01, 0), Vector3.new(0.3, 0.2, 0.16), colors)
		b:layered("TailStalk", Vector3.new(-0.36, 0, 0), Vector3.new(0.12, 0.1, 0.07), colors)
		b:layered("LowerJaw", Vector3.new(0.27, -0.14, 0), Vector3.new(0.38, 0.16, 0.42), colors)
		b:ellipsoid("Mouth", CFrame.new(0.365, -0.065, 0), Vector3.new(0.13, 0.19, 0.34), rgb(48, 12, 18))
		for index = -4, 4 do
			local z = index * 0.032
			local x = 0.43 - math.abs(index) * 0.012
			b:limb(Vector3.new(x, 0.0, z), Vector3.new(x + 0.01, -0.05, z), 0.012, tooth, "Tooth")
			b:limb(Vector3.new(x - 0.01, -0.15, z), Vector3.new(x + 0.005, -0.09, z), 0.012, tooth, "Tooth")
		end
		b:edgeFin(-0.12, -0.3, { 0.06, 0.07, 0.05 }, fin, false, 0.1)
		b:edgeFin(-0.14, -0.3, { 0.05, 0.05 }, fin, true, 0.1)
		b:roundTail(0.12, fin, 0.05)
		b:pectoral(0.0, -0.08, 0.12, 0.08, fin, 0.1)
		b:speckle(36, v2(-0.3, 0.3), v2(-0.05, 0.22), v2(0.015, 0.035), rgb(172, 120, 20))
		-- The illicium arcs forward from the forehead to a glowing esca.
		local base = Vector3.new(0.18, b:top(0.18) - 0.01, 0)
		local bend, tip = Vector3.new(0.34, 0.4, 0), Vector3.new(0.5, 0.34, 0)
		b:limb(base, bend, 0.014, fin, "Filament")
		b:limb(bend, tip, 0.012, fin, "Filament")
		local lure = b:ellipsoid("Lure", CFrame.new(tip + Vector3.new(0.01, -0.025, 0)), Vector3.new(0.05, 0.06, 0.05), rgb(190, 255, 220))
		lure.Material = Enum.Material.Neon
		b:eye(0.26, 0.13, 0.045, rgb(230, 230, 200))
	end,
}
