-- Region and season rules are gameplay choices; the body joins the shared EditableMesh loft pipeline.
return {
	Name = "Red Lionfish",
	ScientificName = "Pterois volitans",
	Rarity = "Rare",
	RarityDenominator = 22,
	MinKg = 0.1,
	AverageKg = 0.9,
	MaxKg = 3.5,
	BaseValue = 137,
	Fight = 0.08,
	Pools = { "PirateCove", "CinderIsles" },
	Seasons = { "Autumn", "Winter" },
	Requires = { "Night" },
	Shapes = {
		Normal = { "#" },
		Big = { "##" },
		Huge = { "##", "##" },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(115, 42, 31), side = rgb(204, 92, 61), belly = rgb(241, 187, 140) }
		local fin = rgb(176, 72, 53)
		local dark, pale = rgb(25, 29, 35), rgb(249, 246, 222)
		b:fishBody(0.30, 0.15, colors, 0.10)
		b:edgeFin(0.20, -0.25, { 0.14, 0.23, 0.24, 0.21, 0.16, 0.09 }, fin, false, 0.2)
		for index = 0, 5 do
		    local x = 0.17 - index * 0.075
		    b:limb(Vector3.new(x, b:top(x), 0), Vector3.new(x - 0.075, b:top(x) + 0.24 - index * 0.014, 0), 0.009, pale, "DorsalSpine")
		end
		b:edgeFin(-0.02, -0.23, { 0.09, 0.11, 0.06 }, fin, true, 0.15)
		b:roundTail(0.14, fin)
		-- Broad paired pectoral fans open out in depth, with long pale rays.
		for _, side in { 1, -1 } do
		    local base = Vector3.new(0.20, -0.03, side * 0.05)
		    b:fin({ base, Vector3.new(0.05, 0.05, side * 0.27), Vector3.new(-0.21, -0.16, side * 0.32), Vector3.new(0.0, -0.23, side * 0.16) }, fin, 0.2)
		    for index = 0, 3 do
		        b:limb(base, Vector3.new(0.04 - index * 0.075, -0.02 - index * 0.06, side * (0.25 + index * 0.025)), 0.008, pale, "PectoralRay")
		    end
		end
		for _, x in { 0.30, 0.17, 0.035, -0.10, -0.23 } do
		    b:marks(x, 0, 0.035, (b:top(x) - b:bottom(x)) * 0.9, pale, v2(-0.2, 1))
		end
		b:eye(0.36, 0.035, 0.05, rgb(173, 109, 55))
	end,
}
