return {
	Name = "Eclipse Ray",
	Rarity = "Mythical",
	RarityDenominator = 260,
	MinKg = 6,
	AverageKg = 28,
	MaxKg = 220,
	LengthScale = 1.15,
	BaseValue = 2400,
	Fight = 0.12,
	Pools = { "OpenSea" },
	Seasons = { "Spring", "Summer", "Autumn", "Winter" },
	Requires = { "BlackHole" },
	Shapes = {
		Normal = { ".#.", "###", ".#." },
		Big = { ".##.", "####", ".##." },
		Huge = { "..#..", ".###.", "#####", ".###.", "..#.." },
	},
	-- Crescent wings surround a dark disc; an illuminated orbit crowns its back.
	Build = function(b, kit)
		local rgb = kit.rgb
		local colors = { back = rgb(9, 5, 18), side = rgb(23, 10, 39), belly = rgb(36, 15, 59) }
		local membrane, violet, lilac = rgb(17, 7, 30), rgb(153, 45, 255), rgb(210, 125, 255)
		local function glow(part)
			if part then
				part.Material = Enum.Material.Neon
				part:SetAttribute("BlackHoleAccent", true)
			end
			return part
		end
		b:beginSkin(colors)
		b:layered("Disc", Vector3.new(0.08, 0.01, 0), Vector3.new(0.61, 0.11, 0.34), colors)
		b:layered("Head", Vector3.new(0.31, 0.005, 0), Vector3.new(0.25, 0.075, 0.25), colors)
		b:layered("TailRoot", Vector3.new(-0.19, 0, 0), Vector3.new(0.22, 0.065, 0.13), colors)
		b:finishSkin()
		for _, side in { -1, 1 } do
			local root = Vector3.new(0.04, 0, side * 0.08)
			local edge = {
				Vector3.new(0.29, 0.012, side * 0.12),
				Vector3.new(0.25, 0.025, side * 0.28),
				Vector3.new(0.12, 0.055, side * 0.46),
				Vector3.new(-0.12, 0.085, side * 0.65),
				Vector3.new(-0.29, 0.06, side * 0.70),
				Vector3.new(-0.18, 0.018, side * 0.44),
				Vector3.new(-0.24, -0.006, side * 0.20),
				Vector3.new(-0.18, -0.01, side * 0.075),
			}
			for index = 1, #edge - 1 do
				b:triangle(root, edge[index], edge[index + 1], membrane)
				glow(b:limb(edge[index], edge[index + 1], 0.011, violet, "WingRim"))
			end
			for _, index in { 3, 4, 6 } do
				local tip = edge[index]
				b:limb(root + Vector3.new(0, 0.005, 0), tip + Vector3.new(0, 0.005, 0), 0.007, rgb(64, 24, 100), "WingRay")
			end
			local horn = {
				Vector3.new(0.36, 0.015, side * 0.105),
				Vector3.new(0.48, 0.035, side * 0.16),
				Vector3.new(0.54, 0.065, side * 0.13),
			}
			b:limb(horn[1], horn[2], 0.045, colors.side, "CephalicHorn")
			glow(b:limb(horn[2], horn[3], 0.018, lilac, "HornTip"))
			glow(b:ellipsoid("Eye", CFrame.new(0.32, 0.049, side * 0.072), Vector3.new(0.037, 0.02, 0.035), lilac))
			for index = 1, 3 do
				glow(b:limb(Vector3.new(0.25 - index * 0.052, -0.027, side * 0.11), Vector3.new(0.22 - index * 0.052, -0.035, side * 0.13), 0.007, violet, "GillSlit"))
			end
		end
		-- The orbit sits just above the dome and leaves its center completely black.
		for index = 1, 16 do
			local a, c = (index - 1) / 16 * math.pi * 2, index / 16 * math.pi * 2
			local function point(angle)
				return Vector3.new(0.08 + math.cos(angle) * 0.102, 0.071, math.sin(angle) * 0.09)
			end
			glow(b:limb(point(a), point(c), 0.008, lilac, "EclipseOrbit"))
		end
		local previous = Vector3.new(-0.23, 0, 0)
		for index = 1, 12 do
			local t = index / 12
			local point = Vector3.new(-0.23 - t * 0.59, -0.005 + t * 0.04, math.sin(t * math.pi * 1.4) * 0.055)
			local tail = b:limb(previous, point, 0.032 * (1 - t) + 0.006, if index > 9 then violet else colors.side, "WhipTail")
			if index > 9 then glow(tail) end
			previous = point
		end
		b.model:SetAttribute("ViewDirection", Vector3.new(0.4, 1, 0.7))
	end,
}
