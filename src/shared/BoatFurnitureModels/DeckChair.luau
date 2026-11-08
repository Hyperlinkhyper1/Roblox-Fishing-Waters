return function(kit)
	local P = kit.Palette
	local W = kit.Material.Wood
	local R = 0.14 -- rail thickness
	local XR = 0.95 -- rail centre line

	-- Pivot points (side view, y/z)
	local backFoot = Vector3.new(0, 0.08, -0.15)
	local backTop = Vector3.new(0, 3.08, 1.5)
	local frontFoot = Vector3.new(0, 0.08, -1.6)
	local frontTop = Vector3.new(0, 1.42, -1.25)
	local seatBack = Vector3.new(0, 1.12, 0.5)
	local propFoot = Vector3.new(0, 0.08, 1.58)
	local propTop = Vector3.new(0, 1.08, 0.62)

	for _, s in { -1, 1 } do
		local x = Vector3.new(XR * s, 0, 0)
		local side = s < 0 and "L" or "R"
		kit.beam("BackRail" .. side, backFoot + x, backTop + x, R, R, P.Teak, W)
		kit.beam("FrontLeg" .. side, frontFoot + x, frontTop + x, R, R, P.Teak, W)
		kit.beam("SideRail" .. side, frontTop + x, seatBack + x, R, R, P.Teak, W)
		kit.beam("PropLeg" .. side, propFoot + x, propTop + x, R, R, P.Teak, W)
		kit.cylinder("Hinge" .. side, 0.12, 0.08, CFrame.new(XR * s + 0.1 * s, 1.1, 0.56) * CFrame.Angles(0, 0, math.pi / 2), P.Brass, kit.Material.Metal)
	end

	local function crossbar(name, pos, d)
		kit.cylinder(name, d, XR * 2 + R, CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), P.DarkWood, W)
	end
	crossbar("TopBar", backTop - Vector3.new(0, 0.02, 0.03), 0.13)
	crossbar("FrontBar", frontTop, 0.13)
	crossbar("FrontStretcher", Vector3.new(0, 0.45, -1.5), 0.1)
	crossbar("RearStretcher", Vector3.new(0, 0.42, 1.4), 0.1)

	-- Striped canvas sling sagging from the top bar to the front bar.
	local top = Vector3.new(0, 3.0, 1.42)
	local sag = Vector3.new(0, 0.82, 0.05)
	local front = Vector3.new(0, 1.42, -1.16)
	local stripes = { P.Red, P.Cream, P.Red }
	for i, c in stripes do
		local o = Vector3.new((i - 2) * 0.56, 0, 0)
		kit.beam("SlingBack" .. i, top + o, sag + o, 0.56, 0.05, c, kit.Material.Fabric)
		kit.beam("SlingSeat" .. i, sag + o, front + o, 0.56, 0.05, c, kit.Material.Fabric)
	end
end
