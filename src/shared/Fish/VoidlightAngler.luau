return {
	Name = "Voidlight Angler",
	Rarity = "Legendary",
	RarityDenominator = 110,
	MinKg = 2,
	AverageKg = 9,
	MaxKg = 75,
	BaseValue = 1250,
	Fight = 0.10,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { "###", "###" },
		Big = { "####", "####", ".##." },
		Huge = { "#####", "#####", "#####" },
	},
	-- A squat abyssal predator whose lantern bends over an oversized, needle-toothed jaw.
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local colors = { back = rgb(8, 5, 15), side = rgb(27, 11, 43), belly = rgb(40, 17, 61) }
		local membrane, violet, lilac = rgb(39, 15, 65), rgb(161, 49, 255), rgb(218, 139, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		b:fishBody(0.43, 0.33, colors, 0.03)
		b:layered("LowerJaw", Vector3.new(0.36, -0.16, 0), Vector3.new(0.29, 0.105, 0.28), colors)
		b:finishSkin()
		b:ellipsoid("Mouth", CFrame.new(0.455, -0.052, 0), Vector3.new(0.12, 0.18, 0.252), rgb(2, 1, 6))
		for _, side in { -1, 1 } do
			glow(b:limb(Vector3.new(0.47, -0.128, side * 0.09), Vector3.new(0.505, -0.03, side * 0.075), 0.013, lilac, "Fang"))
			glow(b:limb(Vector3.new(0.445, 0.029, side * 0.105), Vector3.new(0.49, -0.056, side * 0.09), 0.011, violet, "Fang"))
			for index = 1, 5 do
				local x = 0.22 - index * 0.082
				glow(b:mark(x, -0.025 - math.sin(index * 0.7) * 0.025, side, 0.037, 0.021, violet))
			end
			glow(b:mark(0.285, 0.10, side, 0.07, 0.072, lilac))
			b:mark(0.287, 0.10, side, 0.027, 0.043, rgb(3, 1, 8), nil, 0.005)
		end
		local dorsal = b:edgeFin(0.05, -0.29, { 0.12, 0.035, 0.17, 0.04, 0.13, 0.025 }, membrane)
		local lower = b:edgeFin(-0.08, -0.29, { 0.06, 0.018, 0.09, 0.025 }, membrane, true)
		for _, points in { dorsal, lower } do
			for index = 2, #points - 1 do
				local a, c = points[index], points[index + 1]
				glow(b:limb(Vector3.new(a.X, a.Y, 0), Vector3.new(c.X, c.Y, 0), 0.008, violet, "FinRim"))
			end
		end
		b:forkTail(0.16, 0.065, membrane)
		for _, sign in { -1, 1 } do
			glow(b:limb(Vector3.new(-0.35, sign * 0.022, 0), Vector3.new(-0.5, sign * 0.16, 0), 0.009, violet, "TailRim"))
			b:fin({
				Vector3.new(0.10, -0.045, sign * 0.15),
				Vector3.new(-0.10, -0.13, sign * 0.29),
				Vector3.new(-0.03, -0.16, sign * 0.20),
				Vector3.new(0.12, -0.09, sign * 0.15),
			}, membrane)
			glow(b:limb(Vector3.new(0.10, -0.045, sign * 0.15), Vector3.new(-0.10, -0.13, sign * 0.29), 0.01, violet, "PectoralRim"))
		end
		local lure = {
			Vector3.new(0.18, 0.18, 0), Vector3.new(0.17, 0.32, 0),
			Vector3.new(0.23, 0.44, 0), Vector3.new(0.35, 0.49, 0),
			Vector3.new(0.46, 0.47, 0), Vector3.new(0.51, 0.39, 0),
		}
		for index = 1, #lure - 1 do
			b:limb(lure[index], lure[index + 1], 0.023 - index * 0.002, membrane, "LanternStalk")
		end
		glow(b:ellipsoid("Lantern", CFrame.new(lure[#lure]), Vector3.one * 0.083, lilac))
		glow(b:ellipsoid("LanternHalo", CFrame.new(lure[#lure]), Vector3.one * 0.125, violet, 0.82))
		b.model:SetAttribute("ViewDirection", Vector3.new(0.22, 0.15, 1))
	end,
}
