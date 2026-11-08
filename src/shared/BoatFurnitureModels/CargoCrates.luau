return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local pine = Color3.fromRGB(196, 150, 96)
	local pine2 = Color3.fromRGB(170, 124, 76)
	local batten = Color3.fromRGB(120, 82, 48)
	local strap = Color3.fromRGB(226, 118, 34)

	-- pallet
	kit.block("PalletDeck", Vector3.new(3.5, 0.12, 3.5), CFrame.new(0, 0.24, 0), P.Wood, M.WoodPlanks)
	for _, z in { -1.45, 0, 1.45 } do
		kit.block("PalletRunner", Vector3.new(3.5, 0.18, 0.4), CFrame.new(0, 0.09, z), P.DarkWood, M.Wood)
	end

	-- bottom row: two long crates
	kit.block("CrateLeft", Vector3.new(1.7, 1.5, 3.2), CFrame.new(-0.87, 1.05, 0), pine, M.WoodPlanks)
	kit.block("CrateRight", Vector3.new(1.7, 1.5, 3.2), CFrame.new(0.87, 1.05, 0), pine2, M.WoodPlanks)
	-- left crate front battens + stencil
	kit.block("Batten", Vector3.new(0.16, 1.5, 0.06), CFrame.new(-1.64, 1.05, -1.62), batten, M.Wood)
	kit.block("Batten", Vector3.new(0.16, 1.5, 0.06), CFrame.new(-0.1, 1.05, -1.62), batten, M.Wood)
	kit.block("Stencil", Vector3.new(0.7, 0.36, 0.03), CFrame.new(-1.1, 1.25, -1.615), P.Red, M.SmoothPlastic)
	kit.block("StencilBar", Vector3.new(0.7, 0.08, 0.03), CFrame.new(-1.1, 0.88, -1.615), P.Red, M.SmoothPlastic)
	-- right crate: X-braced front + navy stencil
	kit.beam("Brace", Vector3.new(0.12, 0.42, -1.63), Vector3.new(1.62, 1.68, -1.63), 0.14, 0.05, batten, M.Wood)
	kit.beam("Brace", Vector3.new(0.12, 1.68, -1.63), Vector3.new(1.62, 0.42, -1.63), 0.14, 0.05, batten, M.Wood)
	kit.block("Stencil", Vector3.new(1.1, 0.24, 0.03), CFrame.new(-0.87, 1.6, 1.615), P.Navy, M.SmoothPlastic)
	kit.block("SideStencil", Vector3.new(0.03, 0.5, 1.4), CFrame.new(1.735, 1.1, 0), P.Navy, M.SmoothPlastic)

	-- top crate
	kit.block("CrateTop", Vector3.new(2.2, 1.3, 2.0), CFrame.new(-0.45, 2.45, 0.2), pine, M.WoodPlanks)
	kit.block("TopStencil", Vector3.new(0.7, 0.5, 0.03), CFrame.new(-1.0, 2.5, -0.815), P.Navy, M.SmoothPlastic)
	kit.block("TopLid", Vector3.new(2.26, 0.1, 2.06), CFrame.new(-0.45, 3.13, 0.2), batten, M.Wood)

	-- small crate, slightly turned
	local small = CFrame.new(1.22, 2.2, -0.8) * CFrame.Angles(0, 0.25, 0)
	kit.block("CrateSmall", Vector3.new(0.9, 0.8, 0.9), small, P.Cream, M.WoodPlanks)
	kit.block("SmallStencil", Vector3.new(0.5, 0.2, 0.03), small * CFrame.new(0, 0.05, -0.465), P.Red, M.SmoothPlastic)

	-- cargo strap over the top crate, down to the pallet front and back
	local x = -0.45
	local w, t = 0.32, 0.05
	kit.block("StrapTop", Vector3.new(w, t, 2.12), CFrame.new(x, 3.205, 0.2), strap, M.Fabric)
	kit.block("StrapFrontHigh", Vector3.new(w, 1.42, t), CFrame.new(x, 2.5, -0.83), strap, M.Fabric)
	kit.block("StrapFrontStep", Vector3.new(w, t, 0.86), CFrame.new(x, 1.825, -1.23), strap, M.Fabric)
	kit.block("StrapFrontLow", Vector3.new(w, 1.56, t), CFrame.new(x, 1.06, -1.635), strap, M.Fabric)
	kit.block("StrapBackHigh", Vector3.new(w, 1.42, t), CFrame.new(x, 2.5, 1.23), strap, M.Fabric)
	kit.block("StrapBackStep", Vector3.new(w, t, 0.42), CFrame.new(x, 1.825, 1.42), strap, M.Fabric)
	kit.block("StrapBackLow", Vector3.new(w, 1.56, t), CFrame.new(x, 1.06, 1.635), strap, M.Fabric)
	kit.block("Buckle", Vector3.new(0.4, 0.3, 0.08), CFrame.new(x, 1.2, -1.67), P.Steel, M.Metal)
end
