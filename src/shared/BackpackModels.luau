-- One set of low-poly builders for worn packs, store displays, and 3D previews.
-- Local +Z faces away from the wearer's back. Preview/display parts stay anchored.
local Backpacks = require(script.Parent.BackpackCatalog)
local Models = {}
local rgb = Color3.fromRGB
local V, F = Vector3.new, CFrame.new
local M = Enum.Material
local leather, brass, steel = rgb(78, 52, 35), rgb(194, 153, 69), rgb(47, 58, 66)

function Models.create(id: string): Model
	if not Backpacks.Items[id] then
		id = "Starter"
	end
	local model = Instance.new("Model")
	model.Name = "Backpack_" .. id
	model:SetAttribute("BackpackId", id)
	local function part(name, size, frame, color, material, shape, alpha)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, frame
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.Anchored, p.Massless = true, true
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Transparency = alpha or 0
		p.Parent = model
		return p
	end
	local function ball(name, size, frame, color, material, alpha)
		return part(name, size, frame, color, material, Enum.PartType.Ball, alpha)
	end
	local function cylinder(name, radius, height, frame, color, material, alpha)
		return part(
			name,
			V(height, radius * 2, radius * 2),
			frame * CFrame.Angles(0, 0, math.pi / 2),
			color,
			material,
			Enum.PartType.Cylinder,
			alpha
		)
	end
	local function ring(name, radius, frame, color, thickness, material)
		-- Eight straight segments make a deliberate polygonal hoop.
		local width = thickness or 0.09
		for i = 0, 7 do
			part(
				name,
				V(radius * 0.84, width, width),
				frame * CFrame.Angles(0, 0, i * math.pi / 4) * F(0, radius, 0),
				color,
				material or M.Metal
			)
		end
	end
	-- Rounded outlines made from primitives keep every design asset-free.
	local function panel(name, size, frame, color, material, radius)
		local r = radius or math.min(size.X, size.Y) * 0.16
		part(name, V(size.X - r * 2, size.Y, size.Z), frame, color, material)
		part(name, V(size.X, size.Y - r * 2, size.Z), frame, color, material)
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				cylinder(
					name,
					r,
					size.Z,
					frame * F(x * (size.X / 2 - r), y * (size.Y / 2 - r), 0) * CFrame.Angles(math.pi / 2, 0, 0),
					color,
					material
				)
			end
		end
	end
	local function buckle(frame, width)
		local w = width or 0.25
		for _, side in { -1, 1 } do
			part("BuckleFrame", V(0.045, w, 0.065), frame * F(side * w / 2, 0, 0), brass, M.Metal)
			part("BuckleFrame", V(w, 0.045, 0.065), frame * F(0, side * w / 2, 0), brass, M.Metal)
		end
		part("BuckleTongue", V(0.035, w * 0.75, 0.08), frame, brass, M.Metal)
	end
	local function carryHandle(frame, width, color)
		part("CarryGrip", V(width, 0.12, 0.16), frame * F(0, 0.18, 0), color, M.Fabric)
		for _, side in { -1, 1 } do
			part("HandleMount", V(0.12, 0.24, 0.16), frame * F(side * (width / 2 - 0.06), 0.02, 0), color, M.Fabric)
		end
	end
	local function rivet(x, y, z)
		cylinder("Rivet", 0.045, 0.045, F(x, y, z) * CFrame.Angles(math.pi / 2, 0, 0), brass, M.Metal)
	end
	local handle = part("Handle", V(0.12, 0.12, 0.12), F(), steel, M.SmoothPlastic, nil, 1)
	model.PrimaryPart = handle
	-- Every design has a harness on its inner face.
	for _, side in { -1, 1 } do
		part(
			"ShoulderStrap",
			V(0.22, 1.15, 0.14),
			F(side * 0.5, 0.25, -0.56) * CFrame.Angles(0, 0, side * -0.12),
			leather,
			M.Fabric
		)
		part("StrapTail", V(0.14, 0.65, 0.1), F(side * 0.54, -0.62, -0.54), leather, M.Fabric)
		part("StrapAdjuster", V(0.23, 0.13, 0.12), F(side * 0.54, -0.38, -0.59), steel, M.Metal)
	end
	if id == "Starter" then
		local canvas, fold = rgb(153, 115, 70), rgb(140, 102, 60)
		local rope, thread = rgb(222, 196, 145), rgb(235, 211, 166)
		-- Overlapping soft volumes give the sack a heavy belly and pinched shoulders.
		ball("CanvasPouch", V(1.62, 1.75, 0.98), F(0, -0.24, 0), canvas, M.Fabric)
		ball("CanvasShoulders", V(1.16, 1.12, 0.77), F(0, 0.28, 0), canvas, M.Fabric)
		ball("GatheredNeck", V(0.65, 0.5, 0.51), F(0, 0.69, 0), fold, M.Fabric)
		-- A recessed mouth and splayed pleats replace the solid rectangular top.
		ball("MouthInset", V(0.5, 0.055, 0.36), F(0, 1.025, 0), rgb(92, 65, 39), M.Fabric)
		for i = 0, 7 do
			local angle = i * math.pi / 4
			local x, z = math.cos(angle), math.sin(angle)
			ball(
				"MouthPleat",
				V(0.2, 0.43, 0.18),
				F(x * 0.27, 0.9 + 0.025 * x, z * 0.2) * CFrame.Angles(z * 0.25, -angle, -x * 0.25),
				if i % 2 == 0 then rgb(171, 132, 84) else canvas,
				M.Fabric
			)
		end
		for _, side in { -1, 1 } do
			ball(
				"CanvasFold",
				V(0.15, 0.76, 0.11),
				F(side * 0.37, 0.32, 0.29) * CFrame.Angles(-0.22, 0, side * 0.36),
				fold,
				M.Fabric
			)
			ball(
				"LowerFold",
				V(0.12, 0.42, 0.09),
				F(side * 0.5, -0.65, 0.25) * CFrame.Angles(0.3, side * 0.4, side * -0.4),
				fold,
				M.Fabric
			)
		end
		-- Short round rope segments form a continuous cinch, open bow loops and tails.
		local function cord(name, points, width)
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				cylinder(
					name,
					width / 2,
					(b - a).Magnitude + width * 0.3,
					CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.pi / 2, 0, 0),
					rope,
					M.Fabric
				)
			end
		end
		local cinch = {}
		for i = 0, 12 do
			local angle = i * math.pi / 6
			table.insert(cinch, V(math.cos(angle) * 0.34, 0.67, math.sin(angle) * 0.27))
		end
		cord("RopeCinch", cinch, 0.065)
		for _, side in { -1, 1 } do
			cord("RopeBow", {
				V(0, 0.67, 0.33),
				V(side * 0.23, 0.83, 0.37),
				V(side * 0.42, 0.85, 0.39),
				V(side * 0.49, 0.74, 0.4),
				V(side * 0.36, 0.65, 0.4),
				V(side * 0.16, 0.64, 0.37),
				V(0, 0.67, 0.33),
			}, 0.06)
			local tip = V(side * 0.25, if side == -1 then 0.09 else 0.18, 0.49)
			cord("RopeTail", {
				V(side * 0.04, 0.65, 0.35),
				V(side * 0.14, 0.47, 0.43),
				V(side * 0.17, 0.27, 0.48),
				tip,
			}, 0.06)
			ball("RopeEnd", V(0.085, 0.1, 0.08), F(tip), rope, M.Fabric)
		end
		ball("RopeKnot", V(0.2, 0.15, 0.14), F(0, 0.67, 0.37), thread, M.Fabric)
		local patch = F(0.23, -0.44, 0.456) * CFrame.Angles(0.1, 0.14, -0.14)
		panel("CanvasPatch", V(0.42, 0.36, 0.045), patch, rgb(184, 145, 91), M.Fabric, 0.045)
		for _, side in { -1, 1 } do
			for i = -1, 1 do
				part("PatchStitch", V(0.07, 0.022, 0.025), patch * F(side * 0.18, i * 0.1, 0.03), thread, M.Fabric)
				part("PatchStitch", V(0.022, 0.07, 0.025), patch * F(i * 0.12, side * 0.15, 0.03), thread, M.Fabric)
			end
			-- Curved side seams follow the rounded pouch instead of floating above it.
			local seam = {}
			for i = 0, 8 do
				local angle = -1.12 + i * 0.26
				table.insert(
					seam,
					V(side * 0.7 * math.cos(angle), -0.24 + 0.88 * math.sin(angle), 0.25 * math.cos(angle))
				)
			end
			cord("CanvasSeam", seam, 0.025)
		end
	elseif id == "Satchel" then
		panel("LeatherPiping", V(1.73, 1.73, 0.77), F(0, -0.1, 0), leather, M.Fabric)
		panel("LeatherCase", V(1.65, 1.65, 0.79), F(0, -0.1, 0), rgb(119, 70, 40), M.Fabric)
		panel("Flap", V(1.74, 0.7, 0.15), F(0, 0.5, 0.46), rgb(155, 95, 53), M.Fabric)
		part("ClaspStrap", V(0.19, 0.8, 0.07), F(0, 0.22, 0.57), leather, M.Fabric)
		buckle(F(0, 0.13, 0.64), 0.27)
		carryHandle(F(0, 0.85, 0), 0.65, leather)
		for _, side in { -1, 1 } do
			part("Stitching", V(0.035, 1.38, 0.03), F(side * 0.73, -0.13, 0.4), rgb(226, 190, 126), M.Fabric)
		end
		part("BottomStitching", V(1.4, 0.035, 0.03), F(0, -0.82, 0.41), rgb(226, 190, 126), M.Fabric)
		rivet(-0.69, 0.67, 0.56)
		rivet(0.69, 0.67, 0.56)
	elseif id == "Tackle" then
		panel("SteelCase", V(1.9, 1.4, 0.9), F(0, -0.12, 0), rgb(158, 57, 48), M.Metal, 0.12)
		part("LidGasket", V(1.94, 0.06, 0.94), F(0, 0.51, 0), steel, M.SmoothPlastic)
		panel("Lid", V(1.98, 0.24, 0.98), F(0, 0.65, 0), rgb(196, 73, 57), M.Metal, 0.09)
		part("CarryHandle", V(0.85, 0.12, 0.12), F(0, 0.96, 0), steel, M.Metal)
		for _, side in { -1, 1 } do
			part("HandleMount", V(0.1, 0.3, 0.12), F(side * 0.37, 0.85, 0), steel, M.Metal)
			part("Latch", V(0.19, 0.4, 0.12), F(side * 0.6, 0.35, 0.53), brass, M.Metal)
			part("CornerGuard", V(0.16, 1.4, 0.94), F(side * 0.91, -0.12, 0), steel, M.Metal)
			rivet(side * 0.9, -0.65, 0.5)
			rivet(side * 0.6, 0.37, 0.61)
		end
		panel("TackleBadge", V(0.6, 0.28, 0.06), F(0, -0.03, 0.48), rgb(238, 220, 172), M.Metal, 0.04)
		for _, y in { -0.4, -0.57 } do
			part("PressedRib", V(1.25, 0.045, 0.06), F(0, y, 0.47), rgb(119, 42, 38), M.Metal)
		end
	elseif id == "Creel" then
		panel("Basket", V(1.8, 1.65, 0.95), F(0, -0.12, 0), rgb(163, 123, 62), M.Wood, 0.2)
		for y = -0.8, 0.6, 0.2 do
			part("WickerWeft", V(1.88, 0.07, 1.01), F(0, y, 0), rgb(215, 177, 104), M.Wood)
		end
		for x = -0.8, 0.8, 0.2 do
			part("WickerWarp", V(0.07, 1.6, 0.06), F(x, -0.12, 0.53), rgb(115, 80, 39), M.Wood)
		end
		for _, side in { -1, 1 } do
			for _, z in { -0.3, 0, 0.3 } do
				part("SideWeave", V(0.055, 1.4, 0.07), F(side * 0.92, -0.1, z), rgb(115, 80, 39), M.Wood)
			end
		end
		part("BasketRim", V(1.94, 0.16, 1.04), F(0, 0.67, 0), rgb(92, 63, 34), M.Wood)
		panel("WoodenLid", V(1.96, 0.17, 1.06), F(0, 0.8, 0), rgb(104, 73, 39), M.WoodPlanks, 0.06)
		part("LidStrap", V(0.2, 0.65, 0.1), F(0, 0.45, 0.59), leather, M.Fabric)
		buckle(F(0, 0.3, 0.66), 0.24)
		carryHandle(F(0, 0.98, 0), 0.6, leather)
	elseif id == "Cooler" then
		panel("InsulatedBody", V(1.85, 1.65, 0.95), F(0, -0.15, 0), rgb(55, 139, 182), M.SmoothPlastic, 0.16)
		panel("WhiteLid", V(2, 0.25, 1.08), F(0, 0.8, 0), rgb(226, 239, 233), M.SmoothPlastic, 0.09)
		part("LidSeam", V(1.96, 0.07, 1.04), F(0, 0.64, 0), steel, M.SmoothPlastic)
		for _, side in { -1, 1 } do
			part("SideHandle", V(0.14, 0.55, 0.48), F(side * 1.01, 0.25, 0), rgb(229, 238, 235), M.SmoothPlastic)
		end
		panel("CoolerFoot", V(1.9, 0.21, 1), F(0, -0.93, 0), rgb(30, 83, 110), M.SmoothPlastic, 0.08)
		for _, side in { -1, 1 } do
			part("LidLatch", V(0.19, 0.35, 0.12), F(side * 0.64, 0.54, 0.56), rgb(230, 238, 231), M.SmoothPlastic)
			part("MouldedRib", V(0.07, 0.8, 0.055), F(side * 0.65, -0.2, 0.49), rgb(79, 164, 200), M.SmoothPlastic)
		end
		cylinder(
			"EmblemInset",
			0.38,
			0.055,
			F(0, -0.12, 0.51) * CFrame.Angles(math.pi / 2, 0, 0),
			rgb(37, 109, 151),
			M.SmoothPlastic
		)
		for i = 0, 2 do
			part(
				"SnowflakeArm",
				V(0.055, 0.53, 0.04),
				F(0, -0.12, 0.56) * CFrame.Angles(0, 0, i * math.pi / 3),
				rgb(231, 246, 255),
				M.SmoothPlastic
			)
		end
		cylinder("DrainPlug", 0.075, 0.08, F(0.72, -0.73, 0.52) * CFrame.Angles(math.pi / 2, 0, 0), steel, M.Metal)
	elseif id == "Beacon" then
		cylinder("LanternBase", 0.76, 0.22, F(0, -0.95, 0), brass, M.Metal)
		cylinder("LanternCap", 0.83, 0.2, F(0, 0.92, 0), steel, M.Metal)
		cylinder("LanternCrown", 0.42, 0.3, F(0, 1.15, 0), brass, M.Metal)
		cylinder("LanternGlass", 0.57, 1.55, F(), rgb(239, 202, 128), M.Glass, 0.72)
		cylinder("WarmCore", 0.24, 1.1, F(0, -0.08, 0), rgb(255, 216, 123), M.Neon)
		cylinder("Burner", 0.34, 0.18, F(0, -0.71, 0), steel, M.Metal)
		cylinder("CapStep", 0.65, 0.14, F(0, 1.07, 0), brass, M.Metal)
		for _, y in { -0.77, 0.77 } do
			ring("GlassGuard", 0.63, F(0, y, 0) * CFrame.Angles(math.pi / 2, 0, 0), brass, 0.075)
		end
		for i = 0, 5 do
			local angle = i * math.pi / 3
			part("LanternRib", V(0.1, 1.8, 0.1), F(math.cos(angle) * 0.62, 0, math.sin(angle) * 0.62), brass, M.Metal)
		end
		ring("HandleHoop", 0.3, F(0, 1.48, 0), brass)
		cylinder("WickDial", 0.1, 0.13, F(0.42, -0.83, 0.63) * CFrame.Angles(math.pi / 2, 0, 0), brass, M.Metal)
	elseif id == "Angler" then
		panel("FieldPack", V(1.65, 2, 0.85), F(0, -0.05, 0), rgb(63, 103, 71), M.Fabric)
		panel("TopFlap", V(1.8, 0.4, 1), F(0, 0.86, 0), rgb(94, 133, 81), M.Fabric, 0.13)
		panel("FrontPocket", V(1.2, 0.7, 0.35), F(0, -0.55, 0.56), rgb(111, 138, 89), M.Fabric, 0.12)
		part("PocketZip", V(0.96, 0.045, 0.045), F(0, -0.3, 0.75), steel, M.Metal)
		part("ZipPull", V(0.07, 0.16, 0.05), F(0.37, -0.36, 0.78), brass, M.Metal)
		carryHandle(F(0, 1.13, -0.1), 0.6, leather)
		for _, side in { -1, 1 } do
			part("BuckleStrap", V(0.15, 1.7, 0.1), F(side * 0.48, 0.05, 0.53), leather, M.Fabric)
			cylinder("RodTube", 0.13, 2.45, F(side * 0.98, 0.25, 0), steel, M.Metal)
			cylinder("TubeCap", 0.16, 0.12, F(side * 0.98, 1.48, 0), leather, M.SmoothPlastic)
			panel("SidePocket", V(0.28, 0.68, 0.6), F(side * 0.94, -0.65, 0.03), rgb(85, 120, 72), M.Fabric, 0.08)
			buckle(F(side * 0.48, 0.38, 0.63), 0.22)
		end
	elseif id == "Reef" then
		ball("GlassTank", V(1.85, 1.95, 1.2), F(), rgb(142, 223, 243), M.Glass, 0.67)
		ball("Water", V(1.58, 1.6, 0.96), F(0, -0.13, 0), rgb(64, 167, 217), M.Glass, 0.62)
		cylinder("TankLid", 0.58, 0.15, F(0, 0.92, 0), brass, M.Metal)
		cylinder("TankFoot", 0.65, 0.18, F(0, -0.88, 0), steel, M.Metal)
		carryHandle(F(0, 1.08, 0), 0.52, leather)
		part("SandBed", V(1.1, 0.17, 0.6), F(0, -0.7, 0), rgb(217, 198, 144), M.Sand)
		for i = -1, 1 do
			part(
				"CoralBranch",
				V(0.1, 0.6 + i * 0.12, 0.1),
				F(i * 0.3, -0.37, 0.18) * CFrame.Angles(0, 0, i * 0.3),
				rgb(237, 117, 134),
				M.SmoothPlastic
			)
			part(
				"CoralFork",
				V(0.08, 0.27, 0.08),
				F(i * 0.3 + 0.09, -0.28, 0.18) * CFrame.Angles(0, 0, -0.7),
				rgb(249, 156, 142),
				M.SmoothPlastic
			)
		end
		ball("TinyFish", V(0.6, 0.27, 0.2), F(0.05, 0.12, 0.28), rgb(255, 176, 58), M.SmoothPlastic)
		part(
			"FishTail",
			V(0.18, 0.31, 0.07),
			F(-0.28, 0.12, 0.28) * CFrame.Angles(0, 0, math.pi / 4),
			rgb(255, 214, 90),
			M.SmoothPlastic
		)
		ball("FishEye", V(0.06, 0.06, 0.035), F(0.24, 0.16, 0.38), rgb(26, 43, 50), M.SmoothPlastic)
		for i = 1, 3 do
			ball(
				"AirBubble",
				V(0.065, 0.065, 0.065) * (1 + i * 0.15),
				F(0.4 - i * 0.035, 0.2 + i * 0.17, 0.2),
				rgb(199, 244, 250),
				M.Glass,
				0.3
			)
		end
		for _, side in { -1, 1 } do
			part(
				"TankBrace",
				V(0.09, 1.44, 0.1),
				F(side * 0.74, -0.05, -0.22) * CFrame.Angles(0, 0, side * -0.1),
				brass,
				M.Metal
			)
		end
	elseif id == "Explorer" then
		panel("WaxedCanvas", V(1.7, 2, 0.9), F(0, -0.1, 0), rgb(47, 101, 112), M.Fabric)
		panel("ReinforcedBase", V(1.74, 0.34, 0.96), F(0, -0.98, 0), rgb(30, 65, 73), M.Fabric, 0.11)
		cylinder("RolledTop", 0.23, 1.8, F(0, 0.95, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(76, 133, 139), M.Fabric)
		for _, side in { -1, 1 } do
			part("OrangeWebbing", V(0.16, 2.15, 0.1), F(side * 0.55, -0.03, 0.52), rgb(222, 120, 55), M.Fabric)
			buckle(F(side * 0.55, 0.57, 0.6), 0.23)
		end
		carryHandle(F(0, 1.19, -0.05), 0.6, leather)
		panel("MapPocket", V(0.76, 0.44, 0.14), F(0, -0.65, 0.54), rgb(69, 123, 130), M.Fabric, 0.08)
		part("FoldedMap", V(0.59, 0.23, 0.045), F(0, -0.37, 0.55), rgb(231, 216, 173), M.Fabric)
		part("MapFold", V(0.025, 0.23, 0.02), F(0.06, -0.37, 0.58), rgb(167, 147, 103), M.Fabric)
		cylinder("Compass", 0.24, 0.1, F(0, 0.08, 0.56) * CFrame.Angles(math.pi / 2, 0, 0), brass, M.Metal)
		cylinder(
			"CompassFace",
			0.19,
			0.025,
			F(0, 0.08, 0.625) * CFrame.Angles(math.pi / 2, 0, 0),
			rgb(33, 55, 57),
			M.SmoothPlastic
		)
		part(
			"CompassNeedle",
			V(0.07, 0.31, 0.04),
			F(0, 0.08, 0.64) * CFrame.Angles(0, 0, 0.4),
			rgb(241, 232, 203),
			M.SmoothPlastic
		)
	elseif id == "Treasure" then
		part("ChestBody", V(1.85, 1.3, 1), F(0, -0.35, 0), rgb(112, 67, 39), M.WoodPlanks)
		-- A dark recess and raised lip make the treasure sit inside the chest.
		part("ChestInterior", V(1.53, 0.06, 0.76), F(0, 0.32, 0), rgb(48, 31, 31), M.Wood)
		for _, z in { -0.48, 0.48 } do
			part("ChestRim", V(1.89, 0.13, 0.1), F(0, 0.34, z), leather, M.Wood)
		end
		part(
			"OpenLid",
			V(1.9, 0.18, 1.08),
			F(0, 0.65, -0.2) * CFrame.Angles(-0.8, 0, 0),
			rgb(135, 85, 43),
			M.WoodPlanks
		)
		for _, side in { -1, 1 } do
			part("IronBand", V(0.16, 1.4, 1.08), F(side * 0.7, -0.3, 0), steel, M.Metal)
			part(
				"LidBand",
				V(0.14, 0.21, 1.1),
				F(0, 0.65, -0.2) * CFrame.Angles(-0.8, 0, 0) * F(side * 0.7, 0, 0),
				steel,
				M.Metal
			)
			rivet(side * 0.7, -0.72, 0.56)
			rivet(side * 0.7, 0.14, 0.56)
		end
		part("Lock", V(0.35, 0.4, 0.14), F(0, 0.13, 0.59), brass, M.Metal)
		cylinder("Keyhole", 0.045, 0.025, F(0, 0.17, 0.68) * CFrame.Angles(math.pi / 2, 0, 0), leather, M.Metal)
		part("KeyholeSlot", V(0.04, 0.1, 0.025), F(0, 0.1, 0.68), leather, M.Metal)
		for i = 0, 7 do
			cylinder(
				"GoldCoin",
				0.16,
				0.06,
				F((i % 4 - 1.5) * 0.35, 0.36 + (i % 3) * 0.04, if i < 4 then 0.24 else -0.12),
				rgb(236, 186, 47),
				M.Metal
			)
		end
		ball("Emerald", V(0.3, 0.28, 0.25), F(0.5, 0.5, 0.1), rgb(58, 213, 157), M.Neon)
		part("Ruby", V(0.2, 0.2, 0.2), F(-0.47, 0.48, 0.21) * CFrame.Angles(0.2, 0.4, 0.6), rgb(202, 64, 101), M.Glass)
	elseif id == "Expedition" then
		panel("TrailPack", V(1.75, 2.1, 1), F(0, -0.1, 0), rgb(145, 82, 49), M.Fabric)
		panel("UtilityPocket", V(1.3, 0.8, 0.35), F(0, -0.65, 0.65), rgb(173, 111, 67), M.Fabric, 0.12)
		part("PocketFlap", V(1.37, 0.18, 0.4), F(0, -0.3, 0.68), rgb(193, 135, 82), M.Fabric)
		buckle(F(0, -0.51, 0.88), 0.25)
		cylinder("Bedroll", 0.3, 2.2, F(0, 1.12, 0.1) * CFrame.Angles(0, 0, math.pi / 2), rgb(91, 112, 75), M.Fabric)
		for _, side in { -1, 1 } do
			part("BedrollBelt", V(0.17, 0.66, 0.66), F(side * 0.65, 1.12, 0.1), leather, M.Fabric)
			part("TrailWebbing", V(0.14, 1.35, 0.08), F(side * 0.63, 0.18, 0.56), leather, M.Fabric)
			cylinder(
				"BedrollEnd",
				0.24,
				0.035,
				F(side * 1.12, 1.12, 0.1) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(66, 84, 54),
				M.Fabric
			)
			cylinder(
				"BedrollFold",
				0.13,
				0.045,
				F(side * 1.14, 1.12, 0.1) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(113, 134, 87),
				M.Fabric
			)
		end
		cylinder("TinMug", 0.23, 0.45, F(1.05, -0.6, 0.3), rgb(179, 188, 182), M.Metal)
		ring("MugHandle", 0.15, F(1.27, -0.58, 0.3), steel)
		cylinder("MugRim", 0.25, 0.055, F(1.05, -0.35, 0.3), rgb(216, 225, 218), M.Metal)
		cylinder("MugInterior", 0.19, 0.015, F(1.05, -0.315, 0.3), rgb(46, 57, 55), M.SmoothPlastic)
		panel("SidePouch", V(0.32, 0.7, 0.64), F(-1, -0.55, 0), rgb(111, 70, 46), M.Fabric, 0.09)
	elseif id == "Diving" then
		part("HarnessPlate", V(1.45, 1.85, 0.3), F(0, 0, -0.25), steel, M.Metal)
		for _, side in { -1, 1 } do
			cylinder("OxygenTank", 0.37, 1.7, F(side * 0.48, -0.12, 0.2), rgb(219, 183, 67), M.Metal)
			ball("TankShoulder", V(0.74, 0.4, 0.74), F(side * 0.48, 0.73, 0.2), rgb(232, 205, 107), M.Metal)
			ball("TankBoot", V(0.76, 0.35, 0.76), F(side * 0.48, -0.97, 0.2), steel, M.SmoothPlastic)
			cylinder("Valve", 0.11, 0.24, F(side * 0.48, 1.03, 0.2), brass, M.Metal)
			part("TankBelt", V(0.8, 0.16, 0.8), F(side * 0.48, -0.55, 0.2), steel, M.SmoothPlastic)
			part("UpperTankBelt", V(0.8, 0.13, 0.8), F(side * 0.48, 0.39, 0.2), steel, M.SmoothPlastic)
			part("ValveWheel", V(0.34, 0.07, 0.09), F(side * 0.48, 1.17, 0.2), rgb(183, 64, 46), M.Metal)
			part("TankStripe", V(0.15, 0.53, 0.035), F(side * 0.48, -0.09, 0.58), rgb(246, 229, 167), M.SmoothPlastic)
		end
		ring("AirHose", 0.48, F(0, 0.73, 0.36), rgb(24, 35, 39))
		cylinder("DiveGaugeRim", 0.2, 0.1, F(0, -0.2, 0.68) * CFrame.Angles(math.pi / 2, 0, 0), brass, M.Metal)
		cylinder(
			"DiveGaugeFace",
			0.16,
			0.03,
			F(0, -0.2, 0.75) * CFrame.Angles(math.pi / 2, 0, 0),
			rgb(229, 232, 203),
			M.SmoothPlastic
		)
		part("DiveGaugeNeedle", V(0.025, 0.2, 0.03), F(0, -0.2, 0.78) * CFrame.Angles(0, 0, -0.6), steel, M.Metal)
	elseif id == "Storm" then
		panel("BatteryHousing", V(1.5, 1.9, 0.85), F(), rgb(47, 53, 80), M.Metal, 0.16)
		panel("WindowSurround", V(0.78, 1.65, 0.12), F(0, 0, 0.46), rgb(25, 33, 52), M.Metal, 0.13)
		part("EnergyWindow", V(0.55, 1.45, 0.12), F(0, 0, 0.5), rgb(83, 199, 255), M.Neon)
		for i = -3, 3 do
			for _, side in { -1, 1 } do
				part("CoolingFin", V(0.53, 0.07, 1), F(side * 0.67, i * 0.25, 0), rgb(88, 98, 123), M.Metal)
			end
		end
		for _, side in { -1, 1 } do
			cylinder("Insulator", 0.18, 0.4, F(side * 0.48, 1.1, 0), rgb(213, 228, 234), M.SmoothPlastic)
			for _, y in { 0.98, 1.1, 1.22 } do
				cylinder("CeramicRidge", 0.23, 0.055, F(side * 0.48, y, 0), rgb(177, 195, 211), M.SmoothPlastic)
			end
			ball("Terminal", V(0.32, 0.32, 0.32), F(side * 0.48, 1.4, 0), rgb(98, 218, 255), M.Neon)
			rivet(side * 0.56, -0.83, 0.47)
			rivet(side * 0.56, 0.83, 0.47)
		end
		part("ChargeRail", V(1.12, 0.12, 0.12), F(0, 1.4, -0.08), brass, M.Metal)
		for i = -1, 1 do
			part("ChargeCell", V(0.32, 0.12, 0.07), F(0, i * 0.37, 0.6), rgb(178, 238, 255), M.Neon)
		end
	elseif id == "Lunar" then
		ball("MoonstonePod", V(1.8, 1.9, 1.05), F(0, -0.1, 0), rgb(199, 207, 220), M.Slate)
		for _, crater in { { -0.48, 0.35, 0.35 }, { 0.36, -0.4, 0.25 }, { 0.2, 0.5, 0.2 } } do
			cylinder(
				"Crater",
				crater[3],
				0.05,
				F(crater[1], crater[2], 0.48) * CFrame.Angles(math.pi / 2, 0, 0),
				rgb(126, 142, 164),
				M.Slate
			)
		end
		for _, side in { -1, 1 } do
			part(
				"PodRail",
				V(0.1, 1.55, 0.16),
				F(side * 0.73, -0.12, 0.2) * CFrame.Angles(0, 0, side * 0.16),
				rgb(84, 104, 134),
				M.Metal
			)
		end
		cylinder("MoonBase", 0.65, 0.16, F(0, -0.96, 0), rgb(84, 104, 134), M.Metal)
		part("TelescopeMount", V(0.18, 0.45, 0.18), F(0.45, 0.95, 0), brass, M.Metal)
		local tube = F(0.42, 1.25, 0) * CFrame.Angles(0.45, 0, 0.6)
		cylinder("Telescope", 0.22, 1.25, tube, brass, M.Metal)
		cylinder("TelescopeCollar", 0.255, 0.12, tube * F(0, 0.4, 0), steel, M.Metal)
		cylinder("Eyepiece", 0.13, 0.24, tube * F(0, -0.71, 0), steel, M.Metal)
		cylinder("Lens", 0.25, 0.1, tube * F(0, 0.65, 0), rgb(104, 199, 240), M.Glass)
		cylinder("LensGlass", 0.19, 0.025, tube * F(0, 0.715, 0), rgb(148, 225, 255), M.Glass)
		part(
			"StarBadge",
			V(0.28, 0.28, 0.1),
			F(-0.05, -0.15, 0.6) * CFrame.Angles(0, 0, math.pi / 4),
			rgb(255, 217, 123),
			M.Neon
		)
		for _, star in { { -0.5, -0.31 }, { 0.48, 0.15 }, { 0.27, -0.65 } } do
			ball("StarInlay", V(0.065, 0.065, 0.04), F(star[1], star[2], 0.51), rgb(233, 231, 255), M.Neon)
		end
	elseif id == "Abyss" then
		part("ReactorBackplate", V(1.1, 1.7, 0.22), F(0, 0, -0.4), rgb(36, 49, 62), M.Metal)
		cylinder("AbyssalEnergy", 0.42, 1.5, F(0, 0, 0.18), rgb(93, 245, 202), M.Neon)
		cylinder("PressureGlass", 0.55, 1.6, F(0, 0, 0.18), rgb(99, 181, 188), M.Glass, 0.7)
		for _, y in { -0.95, 0.95 } do
			cylinder("PressureCap", 0.78, 0.19, F(0, y, 0.12), rgb(42, 37, 68), M.Metal)
			cylinder("CapTrim", 0.67, 0.07, F(0, y * 1.14, 0.12), brass, M.Metal)
		end
		ring("PressureRing", 0.68, F(0, 0, 0.18) * CFrame.Angles(math.pi / 2, 0, 0), rgb(42, 37, 68), 0.13)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			part(
				"ContainmentPillar",
				V(0.15, 1.9, 0.15),
				F(math.cos(a) * 0.68, 0, 0.18 + math.sin(a) * 0.68),
				brass,
				M.Metal
			)
		end
		cylinder("PressureGauge", 0.25, 0.11, F(0, 0.65, 0.8) * CFrame.Angles(math.pi / 2, 0, 0), brass, M.Metal)
		cylinder(
			"GaugeFace",
			0.19,
			0.03,
			F(0, 0.65, 0.88) * CFrame.Angles(math.pi / 2, 0, 0),
			rgb(43, 41, 70),
			M.SmoothPlastic
		)
		part(
			"GaugeNeedle",
			V(0.035, 0.27, 0.035),
			F(0, 0.65, 0.91) * CFrame.Angles(0, 0, -0.6),
			rgb(177, 155, 220),
			M.Neon
		)
		for _, side in { -1, 1 } do
			cylinder("PressureValve", 0.13, 0.25, F(side * 0.48, 1.18, 0.12), steel, M.Metal)
			part("ValveGrip", V(0.32, 0.07, 0.09), F(side * 0.48, 1.32, 0.12), brass, M.Metal)
		end
	end
	return model
end

function Models.wear(character: Model, id: string): Model?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return nil
	end
	local old = character:FindFirstChild("FishingBackpack")
	if old then
		old:Destroy()
	end
	local model = Models.create(id)
	model.Name = "FishingBackpack"
	model:ScaleTo(math.clamp(torso.Size.X / 2, 0.65, 1.6))
	local box, size = model:GetBoundingBox()
	model:PivotTo(torso.CFrame * F(0, -0.08, torso.Size.Z / 2 - box.Position.Z + size.Z / 2 + 0.04))
	local handle = model.PrimaryPart
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = handle, piece, piece
		end
	end
	local joint = Instance.new("WeldConstraint")
	joint.Name, joint.Part0, joint.Part1, joint.Parent = "BackWeld", handle, torso, handle
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = false
		end
	end
	model.Parent = character
	return model
end

function Models.show(view: ViewportFrame, id: string)
	view:ClearAllChildren()
	local world = Instance.new("WorldModel")
	world.Parent = view
	local model = Models.create(id)
	model.Parent = world
	local box, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local direction = V(2.5, 1.1, 5).Unit
	camera.CFrame =
		CFrame.lookAt(box.Position + direction * (size.Magnitude / 2 / math.sin(math.rad(17.5)) * 1.12), box.Position)
	camera.Parent, view.CurrentCamera = view, camera
	view.Ambient, view.LightColor = rgb(189, 207, 218), rgb(255, 239, 209)
	view.LightDirection = V(-1, -1, -2)
	return model
end
return Models
