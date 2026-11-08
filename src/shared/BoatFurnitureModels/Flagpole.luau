return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local px = -1.55

	-- Stepped timber base with a brass collar
	kit.block("Base", Vector3.new(0.86, 0.3, 0.9), CFrame.new(px, 0.15, 0), P.DarkWood, M.WoodPlanks)
	kit.block("BaseStep", Vector3.new(0.64, 0.28, 0.66), CFrame.new(px, 0.44, 0), P.Teak, M.Wood)
	kit.cylinder("Collar", 0.36, 0.2, CFrame.new(px, 0.68, 0), P.Brass, M.Metal)

	-- Pole, truck and gilded finial
	kit.cylinder("Pole", 0.2, 9.0, CFrame.new(px, 5.1, 0), P.White, M.SmoothPlastic)
	kit.cylinder("Truck", 0.3, 0.16, CFrame.new(px, 9.62, 0), P.Brass, M.Metal)
	kit.ball("Finial", 0.34, CFrame.new(px, 9.82, 0), P.Brass, M.Metal)

	-- Halyard down the pole to a cleat
	kit.block("Halyard", Vector3.new(0.04, 7.9, 0.04), CFrame.new(px + 0.13, 5.4, 0.1), P.Rope, M.Fabric)
	kit.block("Cleat", Vector3.new(0.08, 0.36, 0.1), CFrame.new(px + 0.13, 1.45, 0.1), P.Brass, M.Metal)

	-- Flag: three bands across X, in three panels zig-zagging so it reads as waving
	local xs = { px + 0.11, -0.36, 0.77, 1.92 }
	local zs = { 0, 0.16, -0.12, 0.14 }
	local bands = {
		{ y = 9.15, color = P.Red },
		{ y = 8.45, color = P.Cream },
		{ y = 7.75, color = P.Navy },
	}
	for i = 1, 3 do
		local drop = (i - 1) * 0.06
		for b, band in bands do
			local a = Vector3.new(xs[i], band.y - drop, zs[i])
			local c = Vector3.new(xs[i + 1], band.y - drop - 0.06, zs[i + 1])
			kit.beam("Flag" .. i .. "_" .. b, a, c, 0.06, 0.7, band.color, M.Fabric)
		end
	end
	-- Brass star emblem on the hoist side of the cream band
	kit.block("Emblem", Vector3.new(0.34, 0.34, 0.08), CFrame.new(-0.9, 8.42, 0.08) * CFrame.Angles(0, -0.14, math.pi / 4), P.Brass, M.Metal)
end
