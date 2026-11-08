return function(kit)
	local P = kit.Palette
	local W = kit.Material.Wood
	local XL = 2.22
	local ZF, ZB = -0.62, 0.66
	local L = 0.22

	for _, s in { -1, 1 } do
		local side = s < 0 and "L" or "R"
		local x = XL * s
		-- Front leg runs up to the armrest, back leg becomes the backrest post.
		kit.block("FrontLeg" .. side, Vector3.new(L, 1.85, L), CFrame.new(x, 0.12 + 1.85 / 2, ZF), P.Teak, W)
		kit.block("BackPost" .. side, Vector3.new(L, 2.6, L), CFrame.new(x, 0.12 + 1.3, ZB), P.Teak, W)
		kit.block("FootCapF" .. side, Vector3.new(0.27, 0.12, 0.27), CFrame.new(x, 0.06, ZF), P.Brass, kit.Material.Metal)
		kit.block("FootCapB" .. side, Vector3.new(0.27, 0.12, 0.27), CFrame.new(x, 0.06, ZB), P.Brass, kit.Material.Metal)
		kit.ball("PostKnob" .. side, 0.3, CFrame.new(x, 2.84, ZB), P.Brass, kit.Material.Metal)
		kit.block("Armrest" .. side, Vector3.new(0.3, 0.12, 1.65), CFrame.new(x, 2.03, -0.02), P.Teak, W)
		kit.block("SideApron" .. side, Vector3.new(0.14, 0.2, ZB - ZF), CFrame.new(x, 1.22, (ZF + ZB) / 2), P.DarkWood, W)
	end

	-- Aprons and stretcher.
	kit.block("FrontApron", Vector3.new(XL * 2 - L, 0.2, 0.12), CFrame.new(0, 1.22, ZF), P.DarkWood, W)
	kit.block("BackApron", Vector3.new(XL * 2 - L, 0.2, 0.12), CFrame.new(0, 1.22, ZB), P.DarkWood, W)
	kit.block("Stretcher", Vector3.new(XL * 2 - L, 0.12, 0.12), CFrame.new(0, 0.45, (ZF + ZB) / 2), P.DarkWood, W)

	-- Seat slats.
	for i = 0, 3 do
		kit.block("BenchSlat" .. i, Vector3.new(XL * 2 - L, 0.12, 0.28), CFrame.new(0, 1.38, -0.6 + i * 0.37), P.Teak, W)
	end

	-- Backrest slats, leaning back slightly between the posts.
	for i = 0, 2 do
		local y = 1.75 + i * 0.36
		kit.block("BackSlat" .. i, Vector3.new(XL * 2 - L, 0.26, 0.08), CFrame.new(0, y, ZB - 0.1 + i * 0.03) * CFrame.Angles(math.rad(-8), 0, 0), P.Teak, W)
	end
end
