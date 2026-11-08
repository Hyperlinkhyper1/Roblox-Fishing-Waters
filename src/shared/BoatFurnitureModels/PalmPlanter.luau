return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Wooden tub with brass bands
	kit.block("PlanterBase", Vector3.new(1.9, 0.2, 1.9), CFrame.new(0, 0.1, 0), P.DarkWood, M.Wood)
	kit.block("PlanterTub", Vector3.new(1.75, 1.3, 1.75), CFrame.new(0, 0.85, 0), P.Teak, M.WoodPlanks)
	kit.block("PlanterBandLow", Vector3.new(1.82, 0.12, 1.82), CFrame.new(0, 0.5, 0), P.Brass, M.Metal)
	kit.block("PlanterBandHigh", Vector3.new(1.82, 0.12, 1.82), CFrame.new(0, 1.2, 0), P.Brass, M.Metal)
	kit.block("PlanterRim", Vector3.new(1.95, 0.14, 1.95), CFrame.new(0, 1.55, 0), P.DarkWood, M.Wood)
	kit.block("PlanterSoil", Vector3.new(1.6, 0.06, 1.6), CFrame.new(0, 1.6, 0), Color3.fromRGB(70, 48, 32), M.Grass)

	-- Segmented, slightly curving trunk
	local bark = { Color3.fromRGB(134, 98, 62), Color3.fromRGB(112, 80, 50) }
	local base = Vector3.new(0, 1.6, 0)
	local top = Vector3.new(0.25, 5.7, 0.05)
	local segments = 4
	local function at(t)
		local p = base:Lerp(top, t)
		return p - Vector3.new(math.sin(t * math.pi) * 0.15, 0, 0)
	end
	for i = 1, segments do
		local a = at((i - 1) / segments)
		local b = at(i / segments)
		local d = 0.55 - i * 0.06
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b) * CFrame.Angles(-math.pi / 2, 0, 0)
		kit.cylinder("PalmTrunk" .. i, d, (b - a).Magnitude + 0.08, cf, bark[(i % 2) + 1], M.Wood)
	end

	-- Crown and coconuts
	kit.ball("PalmCrown", 0.5, CFrame.new(top), Color3.fromRGB(96, 74, 44), M.Wood)
	local nut = Color3.fromRGB(92, 64, 36)
	for i, ang in { 0.4, 2.5, 4.4 } do
		local off = Vector3.new(math.cos(ang) * 0.24, -0.22 - (i % 2) * 0.06, math.sin(ang) * 0.24)
		kit.ball("Coconut" .. i, 0.3, CFrame.new(top + off), nut, M.SmoothPlastic)
	end

	-- Drooping fronds: two beams each, up-and-out then down
	local fronds = 7
	for i = 1, fronds do
		local ang = (i - 1) / fronds * math.pi * 2 + 0.3
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local start = top + Vector3.new(0, 0.1, 0)
		local midH = 6.45 + (i % 2) * 0.2
		local tipH = 5.75 + (i % 3) * 0.2
		local mid = Vector3.new(dir.X * 0.85 + top.X * 0.4, midH, dir.Z * 0.85)
		local tip = Vector3.new(dir.X * 1.4, tipH, dir.Z * 1.4)
		local col = if i % 2 == 0 then P.Leaf else P.Green
		kit.beam("PalmFrond" .. i .. "a", start, mid, 0.5, 0.08, col, M.LeafyGrass)
		kit.beam("PalmFrond" .. i .. "b", mid, tip, 0.3, 0.08, col, M.LeafyGrass)
	end
end
