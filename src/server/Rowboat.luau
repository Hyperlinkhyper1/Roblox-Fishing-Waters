-- Native geometry shared by the drydock display and each player's working boat.
-- The frame origin is the waterline; forward is local -Z. The open hull is built
-- from thin faceted planks instead of a solid block across the passenger space.

local Rowboat = {}

local WOOD = {
	Color3.fromRGB(83, 69, 59),
	Color3.fromRGB(94, 78, 65),
	Color3.fromRGB(104, 86, 71),
	Color3.fromRGB(89, 74, 62),
}
local RAIL = Color3.fromRGB(112, 91, 73)
local IRON = Color3.fromRGB(49, 47, 42)
local LAMP = Color3.fromRGB(255, 218, 151)
local PLANK_THICKNESS = 0.14
local FLOOR_HEIGHT = 0.4
local connectedCoolers = setmetatable({}, { __mode = "k" })

-- Connections are runtime state, so baked shop boats must be rebound on load.
function Rowboat.ensureCoolerInteraction(model: Model)
	local lid = model:FindFirstChild("CoolerLid", true)
	local hinge = if lid then lid:FindFirstChild("CoolerHinge") else nil
	if not hinge or connectedCoolers[lid] then return end
	connectedCoolers[lid] = true
	lid.Anchored = false
	local closed = hinge:GetAttribute("ClosedC0")
	local busy = false
	local function toggle(player: Player)
		local character = player.Character
		local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if busy or not playerRoot or not lid.Parent or (playerRoot.Position - lid.Position).Magnitude > 12 then return end
		busy = true
		local open = not model:GetAttribute("CoolerOpen")
		model:SetAttribute("CoolerOpen", open)
		local tween = game:GetService("TweenService"):Create(hinge,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ C0 = if open then closed * CFrame.Angles(math.rad(-105), 0, 0) else closed })
		tween.Completed:Once(function() busy = false end)
		tween:Play()
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and (piece.Name == "CoolerBody" or piece.Name == "CoolerWall" or piece == lid) then
			local click = piece:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			click.MaxActivationDistance = 12
			click.Parent = piece
			click.MouseClick:Connect(toggle)
		end
	end
end

function Rowboat.build(frame: CFrame, anchored: boolean?): Model
	local isAnchored = anchored == true
	local model = Instance.new("Model")
	model.Name = "Rowboat"
	model:SetAttribute("HullLength", 14.4)
	model:SetAttribute("HullBeam", 6.8)
	model:SetAttribute("DryFloorHeight", FLOOR_HEIGHT)
	model:SetAttribute("DryFloorHalfBeam", 3.25)
	model:SetAttribute("DryFloorHalfLength", 7.1)

	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(3.4, 0.45, 8.5)
	root.CFrame = frame * CFrame.new(0, -0.4, 0)
	root.Transparency = 1
	root.Anchored = isAnchored
	root.CanCollide = false
	root.CanTouch = false
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1.4, 0.45, 0.05, 100, 100)
	root.Parent = model
	model.PrimaryPart = root

	local function finish(p: BasePart, name: string, color: Color3, material: Enum.Material, collide: boolean?)
		p.Name = name
		p.Anchored = isAnchored
		p.CanCollide = collide ~= false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = color
		p.Material = material
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local function part(
		name: string,
		size: Vector3,
		localFrame: CFrame,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = frame * localFrame
		finish(p, name, color, material or Enum.Material.Wood, collide)
		return p
	end

	local function beam(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): Part
		return part(
			name,
			Vector3.new(width, depth, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			color,
			material,
			collide
		)
	end

	-- Two thin wedges cover one triangle. Their thickness is pushed inward, so
	-- adjacent patches share the outside edge without chunky projecting corners.
	local function triangle(name: string, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color3)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		local normal = if right:Dot((a + b + c) / 3 - inside) >= 0 then right else -right
		local shift = -normal * (PLANK_THICKNESS / 2)
		local first = Instance.new("WedgePart")
		first.Size = Vector3.new(PLANK_THICKNESS, height, math.abs(ab:Dot(back)))
		first.CFrame = frame * CFrame.fromMatrix((a + b) / 2 + shift, right, up, back)
		finish(first, name, color, Enum.Material.Wood)
		local second = Instance.new("WedgePart")
		second.Size = Vector3.new(PLANK_THICKNESS, height, math.abs(ac:Dot(back)))
		second.CFrame = frame * CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back)
		finish(second, name, color, Enum.Material.Wood)
	end

	local stations = {
		{ z = -7.1, width = 0.25, bottom = 0.12, top = 2.18 },
		{ z = -4.6, width = 2.73, bottom = 1.70, top = 1.83 },
		{ z = 0, width = 3.25, bottom = 2.08, top = 1.70 },
		{ z = 4.6, width = 2.73, bottom = 1.70, top = 1.83 },
		{ z = 7.1, width = 0.25, bottom = 0.12, top = 2.18 },
	}
	local function hullPoint(station, side: number, level: number): Vector3
		local bottomY = if math.abs(station.z) > 7 then 0.12 else -0.48
		return Vector3.new(
			side * (station.bottom + (station.width - station.bottom) * level),
			bottomY + (station.top - bottomY) * level,
			station.z
		)
	end
	for _, side in { -1, 1 } do
		for i = 1, #stations - 1 do
			local from, to = stations[i], stations[i + 1]
			for band = 0, 1 do
				local low, high = band / 2, (band + 1) / 2
				local a, b = hullPoint(from, side, low), hullPoint(to, side, low)
				local c, d = hullPoint(to, side, high), hullPoint(from, side, high)
				local inside = Vector3.new(0, 0.5, (from.z + to.z) / 2)
				local color = WOOD[(i + band + (if side > 0 then 1 else 0)) % #WOOD + 1]
				triangle("HullPlank", a, b, c, inside, color)
				triangle("HullPlank", a, c, d, inside, color)
			end
			beam("Gunwale", hullPoint(from, side, 1), hullPoint(to, side, 1), 0.24, 0.22, RAIL)
			beam("PlankSeam", hullPoint(from, side, 0.5), hullPoint(to, side, 0.5), 0.065, 0.075, WOOD[1], nil, false)
		end
	end

	-- Terrain water is not displaced by hull parts. A continuous, raised wooden
	-- sole meets the hull at every station, including the tapered bow and stern.
	local function floorPoint(station, side: number): Vector3
		local bottomY = if math.abs(station.z) > 7 then 0.12 else -0.48
		local level = (FLOOR_HEIGHT - bottomY) / (station.top - bottomY)
		return Vector3.new(side * (station.bottom + (station.width - station.bottom) * level), FLOOR_HEIGHT, station.z)
	end
	for i = 1, #stations - 1 do
		local a, b = floorPoint(stations[i], -1), floorPoint(stations[i + 1], -1)
		local c, d = floorPoint(stations[i + 1], 1), floorPoint(stations[i], 1)
		local inside = Vector3.new(0, -1, (a.Z + b.Z) / 2)
		triangle("FloorSeal", a, b, c, inside, WOOD[i % #WOOD + 1])
		triangle("FloorSeal", a, c, d, inside, WOOD[i % #WOOD + 1])
	end

	-- Narrow boards retain the planked appearance above the fitted sole.
	for i = -3, 3 do
		local length = 11.6 - math.abs(i) * 1.0
		part("Floorboard", Vector3.new(0.51, 0.20, length), CFrame.new(i * 0.53, FLOOR_HEIGHT - 0.08, 0), WOOD[(i + 3) % #WOOD + 1])
	end
	part("Keel", Vector3.new(0.26, 0.25, 13.5), CFrame.new(0, -0.51, 0), WOOD[1])
	for _, z in { -7.05, 7.05 } do
		part("Stem", Vector3.new(0.35, 2.05, 0.25), CFrame.new(0, 1.16, z), WOOD[1])
	end
	for _, z in { -3.65, 0.6, 3.65 } do
		local width = if z == 0.6 then 5.55 else 4.9
		part("Bench", Vector3.new(width, 0.24, 1.05), CFrame.new(0, 0.9, z), RAIL)
		for _, side in { -1, 1 } do
			part("BenchSupport", Vector3.new(0.22, 0.9, 0.5), CFrame.new(side * (width / 2 - 0.4), 0.34, z), WOOD[1])
		end
	end

	-- A compact insulated cooler rests on the bow floor ahead of the front bench.
	local coolerBlue = Color3.fromRGB(67, 111, 124)
	local coolerWhite = Color3.fromRGB(230, 230, 211)
	part("CoolerBody", Vector3.new(2, 0.12, 1.4), CFrame.new(0, FLOOR_HEIGHT + 0.08, -4.95), coolerBlue, Enum.Material.SmoothPlastic, false)
	for _, side in { -1, 1 } do
		part("CoolerWall", Vector3.new(0.12, 1.03, 1.4), CFrame.new(side * 0.94, 1.055, -4.95), coolerBlue, Enum.Material.SmoothPlastic, false)
		part("CoolerWall", Vector3.new(1.76, 1.03, 0.12), CFrame.new(0, 1.055, -4.95 + side * 0.64), coolerBlue, Enum.Material.SmoothPlastic, false)
		part("CoolerSeal", Vector3.new(0.14, 0.06, 1.48), CFrame.new(side * 0.97, 1.6, -4.95), IRON, Enum.Material.Rubber, false)
		part("CoolerSeal", Vector3.new(1.8, 0.06, 0.14), CFrame.new(0, 1.6, -4.95 + side * 0.67), IRON, Enum.Material.Rubber, false)
	end
	local lid = part("CoolerLid", Vector3.new(2.15, 0.18, 1.55), CFrame.new(0, 1.72, -4.95), coolerWhite, Enum.Material.SmoothPlastic, false)
	lid:FindFirstChildOfClass("WeldConstraint"):Destroy()
	local pivot = frame * CFrame.new(0, 1.63, -5.725)
	local hinge = Instance.new("Motor6D")
	hinge.Name = "CoolerHinge"
	hinge.Part0, hinge.Part1 = root, lid
	hinge.C0 = root.CFrame:ToObjectSpace(pivot)
	hinge.C1 = lid.CFrame:ToObjectSpace(pivot)
	hinge:SetAttribute("ClosedC0", hinge.C0)
	hinge.Parent = lid
	model:SetAttribute("CoolerOpen", false)
	for _, side in { -1, 1 } do
		part("CoolerLatch", Vector3.new(0.16, 0.32, 0.1), CFrame.new(side * 0.65, 1.48, -4.205), IRON, Enum.Material.Metal, false)
		part("CoolerHandleMount", Vector3.new(0.12, 0.3, 0.75), CFrame.new(side * 1.04, 1.26, -4.95), coolerWhite, Enum.Material.SmoothPlastic, false)
		part("CoolerHandle", Vector3.new(0.16, 0.13, 0.65), CFrame.new(side * 1.15, 1.23, -4.95), IRON, Enum.Material.SmoothPlastic, false)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Size = Vector3.new(2.1, 0.22, 1.05)
	seat.CFrame = frame * CFrame.new(0, 0.92, 0.6)
	seat.Transparency = 1
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	finish(seat, "RowerSeat", RAIL, Enum.Material.Wood, false)
	seat.CanTouch = not isAnchored
	seat.Disabled = isAnchored

	for _, side in { -1, 1 } do
		local inner = Vector3.new(side * 1.9, 1.91, -1.6)
		local outer = Vector3.new(side * 4.66, 1.08, 3.72)
		local shaft = beam("OarShaft", inner, outer, 0.13, 0.13, RAIL, nil, false)
		local grip = beam("OarGrip", inner, inner:Lerp(outer, 0.13), 0.19, 0.18, WOOD[1], nil, false)
		local bladeEnd = outer + (outer - inner).Unit * 1.15
		local blade = beam("OarBlade", outer, bladeEnd, 0.6, 0.13, WOOD[2], nil, false)
		-- One pivot per complete oar. Nothing is also welded directly to the hull.
		local pivot = frame * CFrame.new(side * 3.08, 1.76, 0.6)
		for _, piece in { shaft, grip, blade } do
			piece:FindFirstChildOfClass("WeldConstraint"):Destroy()
			if piece ~= shaft then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = shaft, piece, piece
			end
		end
		local joint = Instance.new("Motor6D")
		joint.Name = if side < 0 then "PortOar" else "StarboardOar"
		joint.Part0, joint.Part1 = root, shaft
		joint.C0 = root.CFrame:ToObjectSpace(pivot)
		joint.C1 = shaft.CFrame:ToObjectSpace(pivot)
		joint:SetAttribute("RowSide", side)
		joint.Parent = shaft
		part(
			"Oarlock",
			Vector3.new(0.15, 0.32, 0.27),
			CFrame.new(side * 3.08, 1.76, 0.6),
			IRON,
			Enum.Material.Metal,
			false
		)
	end

	for _, z in { -6.25, 6.25 } do
		part("EndBoard", Vector3.new(1.45, 0.16, 0.8), CFrame.new(0, 1.95, z), RAIL)
		local base = Vector3.new(0, 2.12, z)
		part("LanternFoot", Vector3.new(0.44, 0.12, 0.44), CFrame.new(base), IRON, Enum.Material.Metal, false)
		local glow = part(
			"LanternGlass",
			Vector3.new(0.28, 0.47, 0.28),
			CFrame.new(base + Vector3.new(0, 0.28, 0)),
			LAMP,
			Enum.Material.Neon,
			false
		)
		part(
			"LanternCap",
			Vector3.new(0.44, 0.12, 0.44),
			CFrame.new(base + Vector3.new(0, 0.56, 0)),
			IRON,
			Enum.Material.Metal,
			false
		)
		for _, x in { -0.18, 0.18 } do
			part(
				"LanternFrame",
				Vector3.new(0.045, 0.49, 0.045),
				CFrame.new(base + Vector3.new(x, 0.29, 0)),
				IRON,
				Enum.Material.Metal,
				false
			)
		end
		part(
			"LanternHandle",
			Vector3.new(0.12, 0.2, 0.05),
			CFrame.new(base + Vector3.new(0, 0.72, 0)),
			IRON,
			Enum.Material.Metal,
			false
		)
		local light = Instance.new("PointLight")
		light.Color = LAMP
		light.Range = 8
		light.Brightness = 0.55
		light.Shadows = false
		light.Parent = glow
	end

	Rowboat.ensureCoolerInteraction(model)
	return model
end

return Rowboat
