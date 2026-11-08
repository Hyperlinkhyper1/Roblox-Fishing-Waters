return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local bamboo = Color3.fromRGB(204, 178, 104)
	local node = Color3.fromRGB(160, 132, 70)

	-- Heavy wooden foot with three splayed bamboo braces.
	kit.cylinder("TorchFoot", 0.95, 0.2, CFrame.new(0, 0.1, 0), P.DarkWood, M.Wood)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		local out = Vector3.new(math.sin(a), 0, -math.cos(a))
		kit.beam("TorchBrace" .. i, out * 0.36 + Vector3.new(0, 0.2, 0), Vector3.new(0, 1.1, 0) + out * 0.08, 0.09, 0.09, node, M.Wood)
	end

	-- Bamboo pole in segments.
	kit.cylinder("TorchPole", 0.22, 4.1, CFrame.new(0, 2.25, 0), bamboo, M.Wood)
	for i, y in { 1.3, 2.4, 3.4 } do
		kit.cylinder("TorchNode" .. i, 0.28, 0.08, CFrame.new(0, y, 0), node, M.Wood)
	end
	kit.cylinder("TorchLashing", 0.3, 0.22, CFrame.new(0, 4.12, 0), P.Rope, M.Fabric)

	-- Woven canister cup.
	kit.cylinder("TorchCupNeck", 0.34, 0.2, CFrame.new(0, 4.34, 0), P.Rope, M.Fabric)
	kit.cylinder("TorchCup", 0.54, 0.46, CFrame.new(0, 4.66, 0), Color3.fromRGB(176, 140, 86), M.Fabric)
	kit.cylinder("TorchCupWeave", 0.58, 0.07, CFrame.new(0, 4.6, 0), P.DarkWood, M.Fabric)
	kit.cylinder("TorchRim", 0.6, 0.07, CFrame.new(0, 4.9, 0), P.Iron, M.Metal)
	kit.cylinder("TorchWick", 0.14, 0.12, CFrame.new(0, 4.98, 0), P.Iron, M.Metal)

	-- Flame.
	local flame = kit.ball("TorchFlame", 0.34, CFrame.new(0, 5.15, 0), P.Flame, M.Neon)
	kit.ball("TorchFlameTip", 0.2, CFrame.new(0, 5.36, 0), P.Glow, M.Neon)
	kit.light(flame, P.Flame, 14, 1.5)
	kit.fire(flame, P.Flame, 1.5)
end
