return {
	Name = "Deepwater Salmon",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 1.5,
	AverageKg = 4,
	MaxKg = 14,
	BaseValue = 155,
	Fight = 0.08,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Winter" },
	Shapes = {
		Normal = { "###" },
		Big = { "####", ".##." },
		Huge = { "#####", "#####" },
	},
	-- Ocean-phase salmon: a blue-grey back, silver flanks and small dark spots.
	Build = function(b, kit)
		local rgb = kit.rgb
		kit.trout(b, {
			colors = { back = rgb(48, 72, 88), side = rgb(170, 190, 198), belly = rgb(232, 238, 236) },
			fin = rgb(88, 110, 122),
			spots = 38,
			spot = rgb(34, 48, 58),
			iris = rgb(190, 202, 174),
			line = rgb(94, 116, 126),
		})
	end,
}
