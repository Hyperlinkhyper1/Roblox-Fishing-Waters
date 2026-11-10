return {
	Name = "Deepwater Eel",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 0.8,
	AverageKg = 3,
	MaxKg = 18,
	LengthScale = 1.3,
	BaseValue = 150,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Autumn" },
	Requires = { "Storm" },
	Shapes = {
		Normal = { "####" },
		Big = { "#####", "#...." },
		Huge = { "######", "#....#" },
	},
	-- Dusky deep-sea eel: near-black purple-brown with big, pale, light-gathering
	-- eyes and a dorsal fin starting just behind the head.
	Build = function(b, kit)
		local rgb, eel = kit.rgb, kit.eel
		eel(b, {
			back = rgb(34, 28, 38),
			side = rgb(62, 52, 64),
			belly = rgb(118, 104, 112),
			fin = rgb(48, 40, 52),
			iris = rgb(190, 214, 220),
			eyeSize = 0.05,
			dorsalFrom = 0.12,
		})
	end,
}
