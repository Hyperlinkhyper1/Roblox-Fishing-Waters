return function(kit)
	local P = kit.Palette
	local W = kit.Material.Wood
	local XR = 1.08

	-- Frame: two long side rails and end rails.
	for _, s in { -1, 1 } do
		local side = s < 0 and "L" or "R"
		kit.block("SideRail" .. side, Vector3.new(0.18, 0.26, 5.9), CFrame.new(XR * s, 0.82, 0), P.Teak, W)
		kit.block("FootLeg" .. side, Vector3.new(0.2, 0.72, 0.22), CFrame.new(XR * s, 0.36, -2.75), P.DarkWood, W)
		kit.block("HeadLeg" .. side, Vector3.new(0.2, 0.5, 0.22), CFrame.new(XR * s, 0.58, 2.2), P.DarkWood, W)
		kit.cylinder("Wheel" .. side, 0.66, 0.14, CFrame.new((XR + 0.02) * s, 0.33, 2.2) * CFrame.Angles(0, 0, math.pi / 2), P.Iron, kit.Material.SmoothPlastic)
		-- Prop strut under the backrest.
		kit.beam("Strut" .. side, Vector3.new((XR - 0.18) * s, 0.95, 2.75), Vector3.new((XR - 0.18) * s, 1.75, 2.15), 0.1, 0.1, P.DarkWood, W)
	end
	kit.block("FootRail", Vector3.new(2.34, 0.26, 0.18), CFrame.new(0, 0.82, -2.86), P.Teak, W)
	kit.block("HeadRail", Vector3.new(2.34, 0.26, 0.18), CFrame.new(0, 0.82, 2.86), P.Teak, W)

	-- Slatted bed under the cushion.
	for i = 0, 4 do
		kit.block("Slat" .. i, Vector3.new(2.0, 0.08, 0.5), CFrame.new(0, 0.95, -2.5 + i * 0.75), P.Wood, W)
	end

	-- Leg cushion with piping band.
	kit.block("Cushion", Vector3.new(2.0, 0.28, 3.7), CFrame.new(0, 1.13, -0.95), P.Teal, kit.Material.Fabric)
	kit.block("CushionBand", Vector3.new(2.04, 0.08, 0.16), CFrame.new(0, 1.15, -2.0), P.Cream, kit.Material.Fabric)
	kit.block("CushionBand2", Vector3.new(2.04, 0.08, 0.16), CFrame.new(0, 1.15, 0.1), P.Cream, kit.Material.Fabric)

	-- Reclined backrest (about 35 degrees) hinged at the cushion's head end.
	local tilt = math.rad(35)
	local len = 1.75
	local hinge = Vector3.new(0, 0.92, 0.95)
	local dir = Vector3.new(0, math.sin(tilt), math.cos(tilt))
	local up = Vector3.new(0, math.cos(tilt), -math.sin(tilt)) -- cushion face normal
	local mid = hinge + dir * (len / 2)
	local backCf = CFrame.lookAt(mid, mid + dir, up)
	kit.block("BackFrame", Vector3.new(2.1, 0.12, len), backCf, P.Wood, W)
	kit.block("BackCushion", Vector3.new(2.0, 0.26, len - 0.1), backCf * CFrame.new(0, 0.19, 0), P.Teal, kit.Material.Fabric)
	kit.block("Pillow", Vector3.new(1.6, 0.16, 0.5), backCf * CFrame.new(0, 0.38, len / 2 - 0.45), P.Cream, kit.Material.Fabric)
end
