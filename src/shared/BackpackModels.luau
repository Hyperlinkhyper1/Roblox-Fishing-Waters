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
	local function ring(name, radius, frame, color)
		-- Eight straight segments make a deliberate polygonal hoop.
		for i = 0, 7 do
			part(
				name,
				V(radius * 0.84, 0.09, 0.1),
				frame * CFrame.Angles(0, 0, i * math.pi / 4) * F(0, radius, 0),
				color,
				M.Metal
			)
		end
	end
	local handle = part("Handle", V(0.12, 0.12, 0.12), F(), steel, M.SmoothPlastic, nil, 1)
	model.PrimaryPart = handle
	-- Every design has a harness on its inner face.
	for _, side in { -1, 1 } do
		part("ShoulderStrap", V(0.18, 1.8, 0.13), F(side * 0.52, 0, -0.54), leather, M.Fabric)
	end
	if id == "Starter" then
		ball("CanvasPouch", V(1.5, 1.6, 0.85), F(0, -0.25, 0), rgb(137, 99, 57), M.Fabric)
		part("GatheredNeck", V(0.72, 0.28, 0.55), F(0, 0.53, 0), rgb(126, 88, 48), M.Fabric)
		part(
			"FoldedMouth",
			V(0.95, 0.38, 0.58),
			F(0.08, 0.8, 0) * CFrame.Angles(0, 0, -0.15),
			rgb(151, 112, 66),
			M.Fabric
		)
		for _, side in { -1, 1 } do
			part(
				"RopeTie",
				V(0.52, 0.09, 0.12),
				F(side * 0.2, 0.53, 0.34) * CFrame.Angles(0, 0, side * 0.35),
				rgb(215, 188, 129),
				M.Fabric
			)
		end
	elseif id == "Satchel" then
		part("LeatherCase", V(1.65, 1.65, 0.75), F(0, -0.1, 0), rgb(119, 70, 40), M.Fabric)
		part("Flap", V(1.74, 0.7, 0.15), F(0, 0.5, 0.46), rgb(155, 95, 53), M.Fabric)
		part("Buckle", V(0.32, 0.34, 0.12), F(0, 0.14, 0.58), brass, M.Metal)
		for _, side in { -1, 1 } do
			part("Stitching", V(0.035, 1.38, 0.03), F(side * 0.73, -0.13, 0.4), rgb(226, 190, 126), M.Fabric)
		end
	elseif id == "Tackle" then
		part("SteelCase", V(1.9, 1.4, 0.9), F(0, -0.12, 0), rgb(158, 57, 48), M.Metal)
		part("Lid", V(1.98, 0.24, 0.98), F(0, 0.65, 0), rgb(196, 73, 57), M.Metal)
		part("CarryHandle", V(0.85, 0.12, 0.12), F(0, 0.96, 0), steel, M.Metal)
		for _, side in { -1, 1 } do
			part("HandleMount", V(0.1, 0.3, 0.12), F(side * 0.37, 0.85, 0), steel, M.Metal)
			part("Latch", V(0.19, 0.4, 0.12), F(side * 0.6, 0.35, 0.53), brass, M.Metal)
			part("CornerGuard", V(0.16, 1.4, 0.94), F(side * 0.91, -0.12, 0), steel, M.Metal)
		end
	elseif id == "Creel" then
		part("Basket", V(1.8, 1.65, 0.95), F(0, -0.12, 0), rgb(163, 123, 62), M.Wood)
		for y = -0.8, 0.6, 0.2 do
			part("WickerWeft", V(1.88, 0.07, 1.01), F(0, y, 0), rgb(215, 177, 104), M.Wood)
		end
		for x = -0.8, 0.8, 0.2 do
			part("WickerWarp", V(0.07, 1.6, 0.06), F(x, -0.12, 0.53), rgb(115, 80, 39), M.Wood)
		end
		part("WoodenLid", V(1.96, 0.17, 1.06), F(0, 0.8, 0), rgb(104, 73, 39), M.WoodPlanks)
		part("LidStrap", V(0.2, 0.65, 0.1), F(0, 0.45, 0.59), leather, M.Fabric)
	elseif id == "Cooler" then
		part("InsulatedBody", V(1.85, 1.65, 0.95), F(0, -0.15, 0), rgb(55, 139, 182), M.SmoothPlastic)
		part("WhiteLid", V(2, 0.25, 1.08), F(0, 0.8, 0), rgb(226, 239, 233), M.SmoothPlastic)
		part("LidSeam", V(1.96, 0.07, 1.04), F(0, 0.64, 0), steel, M.SmoothPlastic)
		for _, side in { -1, 1 } do
			part("SideHandle", V(0.14, 0.55, 0.48), F(side * 1.01, 0.25, 0), rgb(229, 238, 235), M.SmoothPlastic)
		end
		part("SnowflakeVertical", V(0.07, 0.55, 0.05), F(0, -0.12, 0.51), rgb(231, 246, 255), M.SmoothPlastic)
		part("SnowflakeHorizontal", V(0.55, 0.07, 0.05), F(0, -0.12, 0.51), rgb(231, 246, 255), M.SmoothPlastic)
	elseif id == "Beacon" then
		cylinder("LanternBase", 0.76, 0.22, F(0, -0.95, 0), brass, M.Metal)
		cylinder("LanternCap", 0.83, 0.2, F(0, 0.92, 0), steel, M.Metal)
		cylinder("LanternCrown", 0.42, 0.3, F(0, 1.15, 0), brass, M.Metal)
		cylinder("WarmCore", 0.41, 1.4, F(), rgb(255, 216, 123), M.Neon)
		for i = 0, 5 do
			local angle = i * math.pi / 3
			part("LanternRib", V(0.1, 1.8, 0.1), F(math.cos(angle) * 0.62, 0, math.sin(angle) * 0.62), brass, M.Metal)
		end
		ring("HandleHoop", 0.3, F(0, 1.48, 0), brass)
	elseif id == "Angler" then
		part("FieldPack", V(1.65, 2, 0.85), F(0, -0.05, 0), rgb(63, 103, 71), M.Fabric)
		part("TopFlap", V(1.8, 0.4, 1), F(0, 0.86, 0), rgb(94, 133, 81), M.Fabric)
		part("FrontPocket", V(1.2, 0.7, 0.35), F(0, -0.55, 0.56), rgb(111, 138, 89), M.Fabric)
		for _, side in { -1, 1 } do
			part("BuckleStrap", V(0.15, 1.7, 0.1), F(side * 0.48, 0.05, 0.53), leather, M.Fabric)
			cylinder("RodTube", 0.13, 2.45, F(side * 0.98, 0.25, 0), steel, M.Metal)
		end
	elseif id == "Reef" then
		ball("GlassTank", V(1.85, 1.95, 1.2), F(), rgb(142, 223, 243), M.Glass, 0.67)
		ball("Water", V(1.58, 1.6, 0.96), F(0, -0.13, 0), rgb(64, 167, 217), M.Glass, 0.62)
		cylinder("TankLid", 0.58, 0.15, F(0, 0.92, 0), brass, M.Metal)
		part("SandBed", V(1.1, 0.17, 0.6), F(0, -0.7, 0), rgb(217, 198, 144), M.Sand)
		for i = -1, 1 do
			part(
				"CoralBranch",
				V(0.1, 0.6 + i * 0.12, 0.1),
				F(i * 0.3, -0.37, 0.18) * CFrame.Angles(0, 0, i * 0.3),
				rgb(237, 117, 134),
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
	elseif id == "Explorer" then
		part("WaxedCanvas", V(1.7, 2, 0.9), F(0, -0.1, 0), rgb(47, 101, 112), M.Fabric)
		cylinder("RolledTop", 0.23, 1.8, F(0, 0.95, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(76, 133, 139), M.Fabric)
		for _, side in { -1, 1 } do
			part("OrangeWebbing", V(0.16, 2.15, 0.1), F(side * 0.55, -0.03, 0.52), rgb(222, 120, 55), M.Fabric)
		end
		cylinder("Compass", 0.24, 0.1, F(0, 0.08, 0.56) * CFrame.Angles(math.pi / 2, 0, 0), brass, M.Metal)
		part(
			"CompassNeedle",
			V(0.07, 0.31, 0.04),
			F(0, 0.08, 0.64) * CFrame.Angles(0, 0, 0.4),
			rgb(241, 232, 203),
			M.SmoothPlastic
		)
	elseif id == "Treasure" then
		part("ChestBody", V(1.85, 1.3, 1), F(0, -0.35, 0), rgb(112, 67, 39), M.WoodPlanks)
		part(
			"OpenLid",
			V(1.9, 0.18, 1.08),
			F(0, 0.65, -0.2) * CFrame.Angles(-0.8, 0, 0),
			rgb(135, 85, 43),
			M.WoodPlanks
		)
		for _, side in { -1, 1 } do
			part("IronBand", V(0.16, 1.4, 1.08), F(side * 0.7, -0.3, 0), steel, M.Metal)
		end
		part("Lock", V(0.35, 0.4, 0.14), F(0, 0.13, 0.59), brass, M.Metal)
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
	elseif id == "Expedition" then
		part("TrailPack", V(1.75, 2.1, 1), F(0, -0.1, 0), rgb(145, 82, 49), M.Fabric)
		part("UtilityPocket", V(1.3, 0.8, 0.35), F(0, -0.65, 0.65), rgb(173, 111, 67), M.Fabric)
		cylinder("Bedroll", 0.3, 2.2, F(0, 1.12, 0.1) * CFrame.Angles(0, 0, math.pi / 2), rgb(91, 112, 75), M.Fabric)
		for _, side in { -1, 1 } do
			part("BedrollBelt", V(0.17, 0.66, 0.66), F(side * 0.65, 1.12, 0.1), leather, M.Fabric)
		end
		cylinder("TinMug", 0.23, 0.45, F(1.05, -0.6, 0.3), rgb(179, 188, 182), M.Metal)
		ring("MugHandle", 0.15, F(1.27, -0.58, 0.3), steel)
	elseif id == "Diving" then
		part("HarnessPlate", V(1.45, 1.85, 0.3), F(0, 0, -0.25), steel, M.Metal)
		for _, side in { -1, 1 } do
			cylinder("OxygenTank", 0.37, 1.7, F(side * 0.48, -0.12, 0.2), rgb(219, 183, 67), M.Metal)
			ball("TankShoulder", V(0.74, 0.4, 0.74), F(side * 0.48, 0.73, 0.2), rgb(232, 205, 107), M.Metal)
			cylinder("Valve", 0.11, 0.24, F(side * 0.48, 1.03, 0.2), brass, M.Metal)
			part("TankBelt", V(0.8, 0.16, 0.8), F(side * 0.48, -0.55, 0.2), steel, M.SmoothPlastic)
		end
		ring("AirHose", 0.48, F(0, 0.73, 0.36), rgb(24, 35, 39))
	elseif id == "Storm" then
		part("BatteryHousing", V(1.5, 1.9, 0.85), F(), rgb(47, 53, 80), M.Metal)
		part("EnergyWindow", V(0.55, 1.45, 0.12), F(0, 0, 0.5), rgb(83, 199, 255), M.Neon)
		for i = -3, 3 do
			part("CoolingFin", V(1.8, 0.07, 1), F(0, i * 0.25, 0), rgb(88, 98, 123), M.Metal)
		end
		for _, side in { -1, 1 } do
			cylinder("Insulator", 0.18, 0.4, F(side * 0.48, 1.1, 0), rgb(213, 228, 234), M.SmoothPlastic)
			ball("Terminal", V(0.32, 0.32, 0.32), F(side * 0.48, 1.4, 0), rgb(98, 218, 255), M.Neon)
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
		part("TelescopeMount", V(0.18, 0.45, 0.18), F(0.45, 0.95, 0), brass, M.Metal)
		local tube = F(0.42, 1.25, 0) * CFrame.Angles(0.45, 0, 0.6)
		cylinder("Telescope", 0.22, 1.25, tube, brass, M.Metal)
		cylinder("Lens", 0.25, 0.1, tube * F(0, 0.65, 0), rgb(104, 199, 240), M.Glass)
		part(
			"StarBadge",
			V(0.28, 0.28, 0.1),
			F(-0.05, -0.15, 0.6) * CFrame.Angles(0, 0, math.pi / 4),
			rgb(255, 217, 123),
			M.Neon
		)
	elseif id == "Abyss" then
		part("ReactorBackplate", V(1.1, 1.7, 0.22), F(0, 0, -0.4), rgb(36, 49, 62), M.Metal)
		cylinder("AbyssalEnergy", 0.42, 1.5, F(0, 0, 0.18), rgb(93, 245, 202), M.Neon)
		for _, y in { -0.95, 0, 0.95 } do
			cylinder("PressureRing", 0.78, 0.19, F(0, y, 0), rgb(42, 37, 68), M.Metal)
		end
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			part("ContainmentPillar", V(0.15, 1.9, 0.15), F(math.cos(a) * 0.62, 0, math.sin(a) * 0.62), brass, M.Metal)
		end
		ball("PressureGauge", V(0.45, 0.45, 0.13), F(0, 0.65, 0.8), rgb(177, 155, 220), M.Neon)
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
