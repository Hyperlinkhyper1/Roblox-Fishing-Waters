return {
	Name = "Stingray",
	Rarity = "Legendary",
	RarityDenominator = 150,
	MinKg = 6,
	AverageKg = 25,
	MaxKg = 180,
	BaseValue = 500,
	Fight = 0.06,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##.", "###", "##." },
		Big = { "###.", "####", "###." },
		Huge = { "####.", "#####", "####." },
	},
	Build = function(b, kit)
		local rgb, v2 = kit.rgb, kit.v2
		local top, darker, under = rgb(104, 88, 70), rgb(88, 74, 58), rgb(234, 232, 224)
		local half = {
			v2(0.46, 0),
			v2(0.42, 0.08),
			v2(0.34, 0.18),
			v2(0.24, 0.27),
			v2(0.14, 0.31),
			v2(0.04, 0.3),
			v2(-0.06, 0.24),
			v2(-0.13, 0.15),
			v2(-0.17, 0.07),
			v2(-0.18, 0),
		}
		local center = Vector3.new(0.12, 0, 0)
		for _, sign in { 1, -1 } do
			for index = 1, #half - 1 do
				local a, c = half[index], half[index + 1]
				b:triangle(center, Vector3.new(a.X, 0, a.Y * sign), Vector3.new(c.X, 0, c.Y * sign), top)
			end
		end
		local domes = {
			{ Vector3.new(0.13, 0, 0), Vector3.new(0.56, 0.03, 0.54), top },
			{ Vector3.new(0.13, 0.008, 0), Vector3.new(0.46, 0.07, 0.3), top },
			{ Vector3.new(0.07, 0.022, 0), Vector3.new(0.32, 0.05, 0.1), darker },
		}
		for _, dome in domes do
			b:ellipsoid("Disc", CFrame.new(dome[1]), dome[2], dome[3])
		end
		b:ellipsoid("Underside", CFrame.new(0.13, -0.008, 0), Vector3.new(0.56, 0.026, 0.54), under)
		local function height(x: number, z: number): number
			local best = 0.002
			for _, dome in domes do
				local h = dome[2] / 2
				local dx, dz = (x - dome[1].X) / h.X, (z - dome[1].Z) / h.Z
				local remaining = 1 - dx * dx - dz * dz
				if remaining > 0 then
					best = math.max(best, dome[1].Y + h.Y * math.sqrt(remaining))
				end
			end
			return best
		end
		for _ = 1, 54 do
			local x, z = b.random(-0.12, 0.4), b.random(-0.27, 0.27)
			local reach = 0.3 * (1 - math.abs(x - 0.12) / 0.4)
			if math.abs(z) < reach then
				local size = b.random(0.012, 0.032)
				b:ellipsoid(
					"Spot",
					CFrame.new(x, height(x, z) + 0.002, z),
					Vector3.new(size, 0.004, size),
					if b.random(0, 1) > 0.35 then rgb(170, 152, 118) else rgb(66, 54, 42)
				)
			end
		end
		for _, sign in { 1, -1 } do
			b:ellipsoid(
				"Eye",
				CFrame.new(0.3, height(0.3, 0.055 * sign) + 0.008, 0.055 * sign),
				Vector3.new(0.035, 0.028, 0.028),
				rgb(36, 32, 28)
			)
			b:ellipsoid(
				"EyeGlint",
				CFrame.new(0.305, height(0.3, 0.055 * sign) + 0.022, 0.05 * sign),
				Vector3.one * 0.008,
				rgb(255, 255, 255)
			)
			b:ellipsoid(
				"Spiracle",
				CFrame.new(0.255, height(0.255, 0.06 * sign) + 0.002, 0.06 * sign),
				Vector3.new(0.03, 0.006, 0.018),
				rgb(48, 40, 32)
			)
			b:ellipsoid("PelvicFin", CFrame.new(-0.19, 0.004, 0.045 * sign), Vector3.new(0.08, 0.016, 0.05), top)
		end
		-- Many short, overlapping sections give a smooth tapering whip.
		local previous = Vector3.new(-0.16, 0.01, 0)
		for index = 1, 14 do
			local t = index / 14
			local point = Vector3.new(-0.16 - t * 0.46, 0.01 + t * 0.01, math.sin(t * math.pi) * 0.03)
			b:limb(previous:Lerp(point, -0.7), point, 0.04 * (1 - t) + 0.006, darker, "Tail")
			previous = point
		end
		b:limb(Vector3.new(-0.3, 0.03, 0.016), Vector3.new(-0.38, 0.036, 0.024), 0.008, rgb(214, 204, 182), "Barb")
		b.model:SetAttribute("ViewDirection", Vector3.new(0.35, 1, 0.55))
	end,
}
