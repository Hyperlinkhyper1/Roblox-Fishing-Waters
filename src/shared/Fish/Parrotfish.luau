return {
	Name = "Parrotfish",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1.6,
	MaxKg = 9,
	BaseValue = 20,
	Fight = 0.04,
	Pools = { "PirateCove" },
	Seasons = { "Spring", "Summer", "Autumn" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	-- Reef parrotfish that grazes the coral round Pirate Cove: sea-green scales edged in pink,
	-- a fused ivory beak and a crescent tail.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(28, 132, 128), side = rgb(64, 188, 166), belly = rgb(236, 170, 188) }
		local fin = rgb(226, 112, 168)
		local scale = rgb(232, 138, 176)
		b:fishBody(0.3, 0.14, colors, 0.08)
		b:edgeFin(0.2, -0.24, { 0.05, 0.06, 0.06, 0.06, 0.06, 0.055, 0.05 }, fin, false, 0.05)
		b:edgeFin(-0.04, -0.24, { 0.05, 0.05, 0.04 }, fin, true, 0.05)
		b:edgeFin(0.1, 0.02, { 0.05, 0.035 }, fin, true, 0.1)
		b:lunateTail(0.15, fin)
		b:pectoral(0.2, -0.03, 0.1, 0.04, rgb(240, 190, 70), 0.1)
		-- Pink scale edges in staggered rows along the flank.
		for row = 0, 4 do
			local y = -0.06 + row * 0.03
			for x = 0.18 - (row % 2) * 0.025, -0.3, -0.05 do
				if y < b:top(x) - 0.014 and y > b:bottom(x) + 0.014 then
					b:marks(x, y, 0.022, 0.012, scale, v2(0.3, 1))
				end
			end
		end
		-- Bright facial stripes running back from the beak.
		b:stroke({ v2(0.44, 0.0), v2(0.32, 0.03), v2(0.24, 0.035) }, 0.008, rgb(250, 214, 120))
		b:stroke({ v2(0.44, -0.03), v2(0.3, -0.04) }, 0.008, rgb(250, 214, 120))
		local beakY = b:bottom(0.46) * 0.25
		b:ellipsoid("Beak", CFrame.new(0.485, beakY, 0), Vector3.new(0.05, 0.04, 0.045), rgb(238, 232, 214))
		b:face(0.37, 0.04, 0.046, rgb(240, 180, 60), rgb(30, 110, 110))
	end,
}
