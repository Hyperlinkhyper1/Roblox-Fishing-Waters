return {
	Name = "Lingcod",
	Rarity = "Uncommon",
	RarityDenominator = 9,
	MinKg = 1,
	AverageKg = 5,
	MaxKg = 35,
	LengthScale = 1.15,
	BaseValue = 25,
	Fight = 0.05,
	Pools = { "MainLake" },
	Seasons = { "Winter" },
	Requires = { "Storm" },
	Shapes = {
		Normal = { "###" },
		Big = { "###", "###" },
		Huge = { "####", "####" },
	},
	-- Big-headed, big-mouthed bottom dweller mottled in browns and greens.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(86, 82, 58), side = rgb(140, 130, 96), belly = rgb(224, 218, 196) }
		local fin = rgb(110, 100, 70)
		b:fishBody(0.2, 0.14, colors, 0.06)
		-- Broad, flattened head with a huge mouth and jutting lower jaw.
		b:layered("Jaw", Vector3.new(0.36, -0.03, 0), Vector3.new(0.27, 0.15, 0.165), colors)
		b:layered("LowerJaw", Vector3.new(0.44, -0.058, 0), Vector3.new(0.13, 0.05, 0.11), colors)
		-- One long dorsal from nape to tail stalk, notched between spiny and soft parts.
		local spines = b:edgeFin(
			0.2,
			-0.27,
			{ 0.04, 0.055, 0.06, 0.05, 0.025, 0.045, 0.055, 0.06, 0.06, 0.055, 0.05, 0.04 },
			fin,
			false,
			0.05
		)
		b:rays(spines[2], { spines[4], spines[5], spines[6] }, rgb(70, 64, 44))
		b:edgeFin(-0.02, -0.26, { 0.05, 0.055, 0.05, 0.04 }, fin, true)
		b:roundTail(0.11, fin)
		b:pectoral(0.21, -0.05, 0.13, 0.05, fin)
		-- Irregular mottling: clusters of overlapping blotches in dark and copper.
		for _ = 1, 22 do
			local cx, cy = b.random(-0.3, 0.34), b.random(-0.05, 0.09)
			local tone = if b.random(0, 1) > 0.45 then rgb(48, 44, 30) else rgb(150, 132, 78)
			for _ = 1, 3 do
				local x, y = cx + b.random(-0.03, 0.03), cy + b.random(-0.02, 0.02)
				local size = b.random(0.02, 0.04)
				if y < b:top(x) - size * 0.6 and y > b:bottom(x) + size * 0.6 then
					b:marks(x, y, size * 1.3, size * 0.75, tone, v2(1, b.random(-0.6, 0.6)))
				end
			end
		end
		b:stroke({ v2(0.5, -0.035), v2(0.32, -0.075) }, 0.009, rgb(40, 34, 26))
		b:face(0.38, 0.03, 0.042, rgb(200, 180, 90), rgb(90, 86, 60))
	end,
}
