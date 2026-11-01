return {
	Name = "Sockeye Salmon",
	Rarity = "Rare",
	RarityDenominator = 12,
	MinKg = 1,
	AverageKg = 2.7,
	MaxKg = 7,
	BaseValue = 148,
	Fight = 0.07,
	Pools = { "OpenSea" },
	Seasons = { "Autumn" },
	Shapes = {
		Normal = { "###" },
		Big = { "####" },
		Huge = { "####", "####" },
	},
	-- Spawning sockeye: crimson body, olive-green head, a humped back and the
	-- hooked kype jaw of a breeding male.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(160, 26, 28), side = rgb(204, 42, 38), belly = rgb(214, 96, 84) }
		local head = { back = rgb(50, 74, 44), side = rgb(84, 110, 64), belly = rgb(190, 196, 168) }
		local fin = rgb(110, 96, 60)
		b:fishBody(0.24, 0.12, colors, 0.06)
		b:layered("Hump", Vector3.new(0.05, 0.035, 0), Vector3.new(0.42, 0.24, 0.1), colors)
		b:layered("GreenHead", Vector3.new(0.31, -0.012, 0), Vector3.new(0.34, 0.2, 0.112), head)
		-- Hooked upper snout and upturned lower jaw (kype).
		b:layered("Kype", Vector3.new(0.48, -0.012, 0), Vector3.new(0.12, 0.065, 0.06), head)
		b:limb(Vector3.new(0.52, -0.01, 0), Vector3.new(0.545, -0.075, 0), 0.03, head.back, "Kype")
		b:limb(Vector3.new(0.42, -0.075, 0), Vector3.new(0.5, -0.06, 0), 0.026, head.side, "Jaw")
		b:edgeFin(0.08, -0.06, { 0.07, 0.065, 0.05 }, fin)
		b:ellipsoid("AdiposeFin", CFrame.new(-0.25, b:top(-0.25) + 0.004, 0), Vector3.new(0.045, 0.028, 0.012), fin)
		b:edgeFin(-0.12, -0.23, { 0.055, 0.05, 0.035 }, fin, true)
		b:edgeFin(0.02, -0.06, { 0.05, 0.04 }, fin, true)
		b:forkTail(0.12, 0.03, fin)
		b:pectoral(0.2, -0.05, 0.09, 0.035, fin)
		b:face(0.385, 0.028, 0.04, rgb(206, 176, 90), rgb(40, 60, 36))
	end,
}
