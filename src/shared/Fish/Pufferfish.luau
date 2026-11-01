return {
	Name = "Pufferfish",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 0.2,
	AverageKg = 0.9,
	MaxKg = 6,
	BaseValue = 53,
	Fight = 0.02,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "#" },
		Big = { "##", "##" },
		Huge = { ".#.", "###", ".#." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(150, 132, 76), side = rgb(196, 180, 120), belly = rgb(240, 236, 214) }
		local fin = rgb(190, 170, 110)
		b:layered("Body", Vector3.new(0.06, 0, 0), Vector3.new(0.74, 0.58, 0.54), colors)
		b:layered("TailStalk", Vector3.new(-0.3, 0, 0), Vector3.new(0.18, 0.12, 0.1), colors)
		b:edgeFin(-0.2, -0.27, { 0.06, 0.05 }, fin, false, 0.2)
		b:edgeFin(-0.2, -0.27, { 0.06, 0.05 }, fin, true, 0.2)
		b:roundTail(0.11, fin, 0.15)
		b:pectoral(0.18, 0, 0.08, 0.06, fin, 0.25)
		b:speckle(40, v2(-0.25, 0.38), v2(0, 0.26), v2(0.016, 0.03), rgb(70, 60, 36))
		-- Inflated: short spines stand out all over the body.
		for _ = 1, 60 do
			local x, y = b.random(-0.24, 0.36), b.random(-0.25, 0.25)
			local side = if b.random(0, 1) > 0.5 then 1 else -1
			local position, normal = b:surface(x, y, side)
			if position and normal then
				b:limb(position - normal * 0.004, position + normal * 0.04, 0.007, rgb(226, 218, 186), "Spine")
			end
		end
		b:ellipsoid("Beak", CFrame.new(0.43, -0.04, 0), Vector3.new(0.05, 0.05, 0.07), rgb(232, 226, 200))
		b:face(0.3, 0.07, 0.085, rgb(64, 140, 120), rgb(160, 144, 90))
	end,
}
