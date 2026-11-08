return function(kit)
	local P = kit.Palette
	local M = kit.Material
	local up = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis along X

	-- Pedestal on a bolted deck plate
	kit.cylinder("BasePlate", 1.7, 0.16, CFrame.new(0, 0.08, 0.45), P.Steel, M.DiamondPlate)
	kit.cylinder("Pedestal", 0.6, 1.5, CFrame.new(0, 0.9, 0.45), P.Steel, M.Metal)
	kit.cylinder("SwivelCollar", 0.95, 0.18, CFrame.new(0, 1.65, 0.45), P.Iron, M.Metal)

	-- Chair pan and cushion
	kit.block("ChairPan", Vector3.new(2.2, 0.22, 1.8), CFrame.new(0, 1.85, 0.4), P.Teak, M.Wood)
	kit.block("Cushion", Vector3.new(1.9, 0.28, 1.6), CFrame.new(0, 2.1, 0.38), P.White, M.Fabric)
	kit.block("CushionPiping", Vector3.new(1.95, 0.08, 0.08), CFrame.new(0, 2.1, -0.43), P.Navy, M.Fabric)

	-- Reclined backrest
	local back = CFrame.new(0, 3.0, 1.42) * CFrame.Angles(0.12, 0, 0)
	kit.block("Backrest", Vector3.new(2.2, 2.0, 0.24), back, P.Teak, M.Wood)
	kit.block("BackCushion", Vector3.new(1.9, 1.7, 0.2), back * CFrame.new(0, 0.02, -0.22), P.White, M.Fabric)
	kit.block("BackStripe", Vector3.new(0.35, 1.72, 0.04), back * CFrame.new(0, 0.02, -0.34), P.Navy, M.Fabric)
	kit.cylinder("HeadRoll", 0.34, 2.2, back * CFrame.new(0, 1.0, 0) * up, P.Teak, M.Wood)

	-- Armrests
	for _, s in { -1, 1 } do
		local x = 1.2 * s
		kit.block(s < 0 and "ArmLeft" or "ArmRight", Vector3.new(0.3, 0.14, 1.55), CFrame.new(x, 2.75, 0.4), P.Teak, M.Wood)
		kit.block(s < 0 and "ArmPostLeft" or "ArmPostRight", Vector3.new(0.14, 0.75, 0.14), CFrame.new(x, 2.3, -0.2), P.Steel, M.Metal)
		kit.block(s < 0 and "ArmPadLeft" or "ArmPadRight", Vector3.new(0.24, 0.08, 1.0), CFrame.new(x, 2.86, 0.3), P.Navy, M.Fabric)
	end

	-- Rod gimbal between the knees
	kit.block("GimbalMount", Vector3.new(0.3, 0.2, 0.3), CFrame.new(0, 1.85, -0.62), P.Steel, M.Metal)
	kit.cylinder("Gimbal", 0.34, 0.45, CFrame.new(0, 2.05, -0.68) * CFrame.Angles(-0.4, 0, 0), P.Brass, M.Metal)
	kit.cylinder("GimbalPin", 0.08, 0.42, CFrame.new(0, 2.12, -0.71) * up, P.Iron, M.Metal)

	-- Footrest out front
	kit.beam("FootStrut", Vector3.new(0, 1.15, 0.2), Vector3.new(0, 0.62, -1.4), 0.18, 0.18, P.Steel, M.Metal)
	local plate = CFrame.new(0, 0.62, -1.48) * CFrame.Angles(-0.45, 0, 0)
	kit.block("Footplate", Vector3.new(1.6, 0.1, 0.5), plate, P.Teak, M.WoodPlanks)
	kit.block("FootLip", Vector3.new(1.6, 0.18, 0.08), plate * CFrame.new(0, 0.09, -0.22), P.Steel, M.Metal)
end
