return function(kit)
	local P = kit.Palette
	local M = kit.Material

	-- Weighted iron foot and post.
	kit.cylinder("LanternFoot", 1.1, 0.14, CFrame.new(0, 0.07, 0), P.Iron, M.Metal)
	kit.cylinder("LanternFootStep", 0.7, 0.16, CFrame.new(0, 0.22, 0), P.Iron, M.Metal)
	kit.cylinder("LanternPost", 0.18, 3.1, CFrame.new(0, 1.85, 0), P.Iron, M.Metal)
	kit.cylinder("LanternPostRing", 0.28, 0.1, CFrame.new(0, 1.2, 0), P.Brass, M.Metal)
	kit.cylinder("LanternCollar", 0.38, 0.14, CFrame.new(0, 3.4, 0), P.Brass, M.Metal)

	-- Lantern cage.
	kit.block("LanternBase", Vector3.new(0.86, 0.12, 0.86), CFrame.new(0, 3.53, 0), P.Iron, M.Metal)
	kit.block("LanternTop", Vector3.new(0.86, 0.12, 0.86), CFrame.new(0, 4.52, 0), P.Iron, M.Metal)
	local core = kit.block("LanternFlame", Vector3.new(0.5, 0.82, 0.5), CFrame.new(0, 4.02, 0), P.Glow, M.Neon)
	kit.light(core, P.Glow, 14, 1.4)
	for i, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		kit.block(
			"LanternCorner" .. i,
			Vector3.new(0.1, 0.9, 0.1),
			CFrame.new(c[1] * 0.37, 4.02, c[2] * 0.37),
			P.Iron,
			M.Metal
		)
	end
	-- Brass mid band round the glass.
	kit.block("LanternBandFront", Vector3.new(0.8, 0.06, 0.06), CFrame.new(0, 4.02, -0.37), P.Brass, M.Metal)
	kit.block("LanternBandBack", Vector3.new(0.8, 0.06, 0.06), CFrame.new(0, 4.02, 0.37), P.Brass, M.Metal)
	kit.block("LanternBandLeft", Vector3.new(0.06, 0.06, 0.8), CFrame.new(-0.37, 4.02, 0), P.Brass, M.Metal)
	kit.block("LanternBandRight", Vector3.new(0.06, 0.06, 0.8), CFrame.new(0.37, 4.02, 0), P.Brass, M.Metal)

	-- Hipped roof from four wedges, finial on top.
	for i = 0, 3 do
		local rot = CFrame.Angles(0, i * math.pi / 2, 0)
		kit.wedge(
			"LanternRoof" .. i,
			Vector3.new(0.96, 0.3, 0.48),
			CFrame.new(0, 4.73, 0) * rot * CFrame.new(0, 0, -0.24),
			P.Iron,
			M.Metal
		)
	end
	kit.ball("LanternFinial", 0.2, CFrame.new(0, 4.89, 0), P.Brass, M.Metal)
end
