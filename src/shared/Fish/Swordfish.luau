return {
	Name = "Swordfish",
	Rarity = "Epic",
	RarityDenominator = 30,
	MinKg = 20,
	AverageKg = 90,
	MaxKg = 600,
	LengthScale = 1.5,
	BaseValue = 408,
	Fight = 0.06,
	Pools = { "OpenSea" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####", ".###." },
		Huge = { "#######", ".#####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(54, 46, 66), side = rgb(126, 118, 132), belly = rgb(214, 208, 204) }
		local fin = rgb(60, 52, 70)
		b:fishBody(0.2, 0.16, colors, 0.02)
		-- Heavy shoulders behind the head.
		b:layered("Shoulder", Vector3.new(0.2, 0.012, 0), Vector3.new(0.34, 0.215, 0.175), colors)
		local crest = b:top(0.12)
		b:fin({
			v2(0.25, b:top(0.25) - 0.008),
			v2(0.15, crest + 0.12),
			v2(0.07, crest + 0.165),
			v2(0.1, crest + 0.07),
			v2(0.11, crest + 0.02),
			v2(0.12, crest - 0.008),
		}, fin)
		local keel = b:bottom(0)
		b:fin(
			{ v2(0.04, keel + 0.008), v2(-0.08, keel - 0.12), v2(-0.06, keel - 0.03), v2(-0.04, b:bottom(-0.04) + 0.008) },
			fin
		)
		b:edgeFin(-0.24, -0.29, { 0.03 }, fin)
		b:edgeFin(-0.24, -0.29, { 0.03 }, fin, true)
		b:ellipsoid("Keel", CFrame.new(-0.33, 0, 0), Vector3.new(0.08, 0.03, b:top(-0.33) * 1.4), colors.back)
		b:lunateTail(0.22, fin)
		b:pectoral(0.22, -0.05, 0.14, 0.05, fin)
		-- The flat sword is about a third of the fish's whole length.
		b:ellipsoid("Sword", CFrame.new(0.72, 0.005, 0), Vector3.new(0.58, 0.022, 0.08), rgb(40, 34, 46))
		b:face(0.36, 0.025, 0.065, rgb(60, 70, 90), rgb(80, 70, 90))
	end,
}
