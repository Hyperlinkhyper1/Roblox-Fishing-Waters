-- Three walk-through cars. The server builds a small invisible collision hull;
-- clients build the detailed body and animate it from MetroSchedule without replication spam.
local Train = {}
local V, rgb, M = Vector3.new, Color3.fromRGB, Enum.Material
local CREAM, TEAL = rgb(239, 231, 209), rgb(35, 88, 81)
local DARK, RED = rgb(29, 38, 40), rgb(152, 62, 44)
local BRASS, STEEL = rgb(192, 155, 82), rgb(159, 174, 169)
local GLASS = rgb(83, 125, 131)
local poses = setmetatable({}, { __mode = "k" })

-- `pace`, when supplied by a client, yields between small groups of parts. The
-- model must already be in Workspace so each group is registered separately.
function Train.build(parent, dock, collisionOnly, pace)
	local model = Instance.new("Model")
	model.Name = if collisionOnly then "TrainCollision" else "LineOneTrain"
	model:SetAttribute("LodSkip", true)
	if pace then model.Parent = parent end
	local doors = {}
	local function p(name, x, y, z, w, h, d, color, material, solid)
		if pace then pace(model) end
		local part = Instance.new("Part")
		part.Name, part.Size = name, V(w, h, d)
		part.CFrame = dock * CFrame.new(x, y, z)
		part.Anchored, part.CanTouch = true, false
		part.CanCollide = collisionOnly and solid == true
		part.CanQuery = collisionOnly
		part.Color, part.Material = color or CREAM, material or M.Metal
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Transparency = if collisionOnly then 1 else 0
		part.CastShadow = false
		part.Parent = model
		return part
	end
	local function label(part, words, face, color)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.PixelsPerStud = face or Enum.NormalId.Front, 32
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.LightInfluence, gui.MaxDistance = 0.15, 180
		gui.Parent = part
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		text.Text, text.TextColor3, text.TextScaled = words, color or CREAM, true
		text.Font, text.Parent = Enum.Font.GothamMedium, gui
	end
	local function cylinder(name, x, y, z, length, diameter, color, rotation)
		local part = p(name, x, y, z, length, diameter, diameter, color)
		part.Shape = Enum.PartType.Cylinder
		if rotation then part.CFrame *= rotation end
		return part
	end
	for car, cx in { -46, 0, 46 } do
		p("CarriageFloor", cx, -0.35, 0, 44, 0.7, 10, DARK, M.Metal, true)
		if collisionOnly then
			p("CarriageRoof", cx, 9.4, 0, 44.6, 0.8, 10.6, TEAL, M.Metal, true)
		else
			-- A shallow, faceted crown gives the coach a rounded silhouette.
			p("CarriageRoof", cx, 9.42, 0, 44.3, 0.6, 7.2, TEAL)
			for _, side in { -1, 1 } do
				local shoulder = p("RoofShoulder", cx, 9.12, side * 4.23, 44.42, 0.5, 1.75, TEAL)
				shoulder.CFrame *= CFrame.Angles(side * math.rad(25), 0, 0)
			end
		end
		for _, side in { -1, 1 } do
			local z = side * 5
			-- Solid wall runs stop at the two real door openings.
			for _, run in { { -22, -13.8 }, { -8.2, 8.2 }, { 13.8, 22 } } do
				local first, last = run[1], run[2]
				if not collisionOnly then
					-- Pull the outer side panels back into the chamfered cab corners.
					if cx == -46 and first == -22 then first = -20.8 end
					if cx == 46 and last == 22 then last = 20.8 end
				end
				local x, width = cx + (first + last) / 2, last - first
				p("LowerBody", x, 1.7, z, width, 3.4, 0.35, TEAL, M.Metal, true)
				if collisionOnly then
					p("WindowGlass", x, 5.45, z, width, 4.1, 0.28, GLASS, M.Glass, true)
				else
					p("WindowSill", x, 3.5, z, width, 0.2, 0.42, CREAM)
					p("WindowHeader", x, 7.3, z, width, 0.2, 0.42, CREAM)
					p("CoachWaistStripe", x, 3.27, side * 5.22, width, 0.12, 0.08, BRASS)
					p("BodySkirt", x, 0.35, side * 5.21, width - 0.12, 0.48, 0.1, DARK)
					local count = if first == -8.2 then 3 else 2
					local cell = width / count
					for boundary = 0, count do
						local edge = if boundary == 0 then 0.15 elseif boundary == count then -0.15 else 0
						p("WindowPillar", cx + first + boundary * cell + edge, 5.4, z, 0.3, 3.6, 0.4, CREAM)
					end
					for windowIndex = 1, count do
						local left = first + (windowIndex - 1) * cell + (if windowIndex == 1 then 0.3 else 0.15)
						local right = first + windowIndex * cell - (if windowIndex == count then 0.3 else 0.15)
						local glass = p("WindowGlass", cx + (left + right) / 2, 5.4, z, right - left, 3.6, 0.18, GLASS, M.Glass)
						glass.Transparency, glass.Reflectance = 0.28, 0.08
					end
				end
			end
			p("UpperBody", cx, if collisionOnly then 8.4 else 8.05, z, 44, if collisionOnly then 1.8 else 1.3, 0.4, CREAM, M.Metal, true)
			for _, dx in { -11, 11 } do
				-- Meet the floor edge without laying a second face over its top.
				p("DoorThreshold", cx + dx, -0.18, side * 5.65, 5.6, 0.36, 1.3, DARK, M.Metal, true)
				for _, half in { -1, 1 } do
					local doorX = cx + dx + half * 1.4
					local function leaf(name, offset, y, w, h, d, color, material, depth)
						-- Moving details stay axis-aligned so their local X is the slide axis.
						local part = p(name, doorX + offset, y, side * (depth or 5.4), w, h, d, color, material, true)
						table.insert(doors, { part = part, closed = dock:ToObjectSpace(part.CFrame), direction = half })
						return part
					end
					if collisionOnly then
						local door = p("SlidingDoor", doorX, 3.8, z - side * 0.15, 2.76, 7.6, 0.3, RED, M.Metal, true)
						table.insert(doors, { part = door, closed = dock:ToObjectSpace(door.CFrame), direction = half })
					else
						-- Open glass apertures, rather than glass laid on an opaque door.
						leaf("SlidingDoor", 0, 1.575, 2.76, 3.15, 0.2, RED)
						leaf("DoorMidRail", 0, 3.325, 2.76, 0.35, 0.2, RED)
						leaf("DoorTopRail", 0, 7.3, 2.76, 0.6, 0.2, RED)
						for _, edge in { -1, 1 } do
							leaf("DoorStile", edge * 1.15, 5.25, 0.46, 3.5, 0.2, RED)
						end
						local glass = leaf("DoorWindow", 0, 5.25, 1.84, 3.5, 0.12, GLASS, M.Glass)
						glass.Transparency, glass.Reflectance = 0.24, 0.06
						leaf("DoorHandle", -half * 0.95, 2.4, 0.13, 0.7, 0.12, BRASS, M.Metal, 5.55)
						leaf("DoorKickPlate", 0, 0.4, 2.42, 0.44, 0.06, STEEL, M.Metal, 5.53)
					end
				end
				if not collisionOnly then
					p("DoorWarningLight", cx + dx, 7.91, side * 5.26, 1.2, 0.16, 0.08, BRASS, M.Neon)
				end
			end
		end
		for _, dx in { -21.7, 21.7 } do
			-- End bulkheads leave a gangway between cars.
			-- The outer cabs already provide their own complete end wall.
			if math.abs(cx + dx) > 67 then continue end
			for _, side in { -1, 1 } do
				p("EndBulkhead", cx + dx, 4.5, side * 3.4, 0.4, 9, 3.2, CREAM, M.Metal, true)
			end
		end
		if not collisionOnly then
			p("InteriorCeiling", cx, 8.72, 0, 42, 0.16, 9.3, CREAM)
			p("AisleFloor", cx, 0.035, 0, 42, 0.07, 4.8, rgb(111, 120, 110), M.SmoothPlastic)
			for _, side in { -1, 1 } do
				local strip = p("CeilingLight", cx, 8.59, side * 2.6, 36, 0.1, 0.32, rgb(255, 229, 178), M.Neon)
				for _, dx in { -12, 0, 12 } do
					local attachment = Instance.new("Attachment")
					attachment.Position = V(dx, -0.1, 0)
					attachment.Parent = strip
					local light = Instance.new("PointLight")
					light.Color, light.Brightness, light.Range = rgb(255, 229, 190), 1.5, 18
					light.Shadows, light.Parent = false, attachment
				end
			end
			for _, side in { -1, 1 } do
				for _, dx in { -18, 0, 18 } do
					local width = if dx == 0 then 12 else 5
					p("SeatPlinth", cx + dx, 0.92, side * 3.8, width - 0.2, 1.34, 1.3, DARK)
					local count = if dx == 0 then 5 else 2
					local pitch = width / count
					for seat = 1, count do
						local sx = cx + dx - width / 2 + (seat - 0.5) * pitch
						p("SeatCushion", sx, 1.9, side * 3.55, pitch - 0.12, 0.55, 1.94, RED, M.Fabric)
						local back = p("SeatBack", sx, 3.12, side * 4.22, pitch - 0.14, 1.9, 0.38, RED, M.Fabric)
						back.CFrame *= CFrame.Angles(side * math.rad(7), 0, 0)
					end
					for _, edge in { -1, 1 } do
						p("SeatArmrest", cx + dx + edge * (width / 2 + 0.04), 2.62, side * 3.65, 0.12, 0.16, 1.65, BRASS)
					end
				end
				for _, dx in { -7.7, 7.7 } do
					cylinder("GrabPole", cx + dx, 4.32, side * 2.5, 8.5, 0.14, BRASS, CFrame.Angles(0, 0, math.pi / 2))
				end
				cylinder("OverheadRail", cx, 7.75, side * 2.5, 15.4, 0.14, BRASS)
				for _, dx in { -4.5, 4.5 } do
					for _, edge in { -1, 1 } do
						p("HangingStrap", cx + dx + edge * 0.26, 7.37, side * 2.5, 0.08, 0.66, 0.12, rgb(214, 206, 180), M.Fabric)
					end
					cylinder("HangingGrip", cx + dx, 7.04, side * 2.5, 0.6, 0.13, BRASS)
				end
				local route = p("InteriorRouteMap", cx, 7.95, side * 4.73, 11, 0.65, 0.1, TEAL)
				label(route, "1  GULLHAVEN  ──  HAFEN MITTE", if side < 0 then Enum.NormalId.Back else Enum.NormalId.Front)
				local face = if side < 0 then Enum.NormalId.Front else Enum.NormalId.Back
				local badge = p("LineBadge", cx - 6.1, 8.05, side * 5.26, 0.8, 0.8, 0.08, TEAL)
				label(badge, "1", face)
				local destination = p("SideDestination", cx + 0.5, 8.05, side * 5.26, 10.8, 0.7, 0.08, DARK)
				label(destination, "GULLHAVEN ↔ HAFEN MITTE", face, BRASS)
				local fleet = p("FleetPlate", cx + 17, 1.4, side * 5.23, 2.6, 0.6, 0.06, TEAL)
				label(fleet, "FW 10" .. car, face)
			end
			p("ChassisBeam", cx, -0.89, 0, 41, 0.36, 6, DARK)
			for _, dx in { -5, 5 } do
				p("UnderfloorEquipment", cx + dx, -1.48, 0, 6.4, 0.8, 5.5, rgb(65, 77, 74))
			end
			for _, dx in { -15.5, 15.5 } do
				p("BogieFrame", cx + dx, -1.28, 0, 7, 0.8, 6.5, DARK)
				for _, side in { -1, 1 } do
					p("BogieSideFrame", cx + dx, -1.45, side * 3.25, 6.8, 0.5, 0.32, STEEL)
					cylinder("BogieSuspension", cx + dx, -1.04, side * 3.5, 3.1, 0.28, DARK)
				end
				for _, axle in { -2, 2 } do
					p("WheelAxle", cx + dx + axle, -1.75, 0, 0.32, 0.32, 7.5, DARK)
					for _, side in { -1, 1 } do
						cylinder("Wheel", cx + dx + axle, -1.75, side * 3.65, 0.55, 2.15, DARK, CFrame.Angles(0, math.pi / 2, 0))
						cylinder("WheelHub", cx + dx + axle, -1.75, side * 3.96, 0.12, 0.95, STEEL, CFrame.Angles(0, math.pi / 2, 0))
					end
				end
			end
			for _, dx in { -7, 7 } do
				p("RoofVent", cx + dx, 9.99, 0, 6.2, 0.48, 3.4, rgb(103, 117, 113))
				for slat = -2, 2 do
					p("RoofVentSlat", cx + dx + slat * 0.9, 10.25, 0, 0.32, 0.08, 2.9, DARK)
				end
			end
		end
	end
	for _, x in { -23, 23 } do
		p("GangwayFloor", x, -0.35, 0, 2, 0.7, 4, DARK, M.Metal, true)
		p("GangwayRoof", x, 8.8, 0, 2, 0.3, 4.8, DARK, M.Metal, true)
		for _, side in { -1, 1 } do
			p("GangwayWall", x, 4.3, side * 2.3, 2, 8.6, 0.32, DARK, M.Metal, true)
			if not collisionOnly then
				for _, fold in { -0.68, 0, 0.68 } do
					p("GangwayBellow", x + fold, 4.32, side * 2.54, 0.25, 8.5, 0.24, rgb(66, 76, 72))
				end
			end
		end
	end
	for _, side in { -1, 1 } do
		if collisionOnly then
			p("CabEnd", side * 68, 4.5, 0, 0.4, 9, 10, TEAL, M.Metal, true)
		else
			local rake = CFrame.Angles(0, 0, side * math.rad(8))
			p("CabApron", side * 68.12, 1.65, 0, 0.55, 3.3, 8.3, TEAL)
			for _, corner in { -1, 1 } do
				local cheek = p("CabCorner", side * 67.77, 4.4, corner * 4.62, 0.28, 8.72, 1.55, CREAM)
				cheek.CFrame *= CFrame.Angles(0, -side * corner * math.pi / 4, 0)
			end
			local glass = p("CabWindscreen", side * 68.25, 5.4, 0, 0.12, 3.7, 8.1, rgb(42, 76, 85), M.Glass)
			glass.CFrame *= rake
			glass.Transparency, glass.Reflectance = 0.2, 0.1
			local mullion = p("CabWindscreenMullion", side * 68.25, 5.4, 0, 0.22, 3.76, 0.13, DARK)
			mullion.CFrame *= rake
			local sill = p("CabWindscreenSill", side * 68.53, 3.43, 0, 0.3, 0.3, 8.32, DARK)
			sill.CFrame *= rake
			local brow = p("CabBrow", side * 67.9, 8.03, 0, 0.5, 1.55, 8.3, CREAM)
			brow.CFrame *= rake
			local destination = p("DestinationDisplay", side * 68.18, 8.03, 0, 0.1, 0.86, 7.1, DARK)
			destination.CFrame *= rake
			label(destination, "1  GULLHAVEN ↔ HAFEN MITTE", if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left, BRASS)
			for _, z in { -1.8, 1.8 } do
				local wiper = p("CabWiper", side * 68.4, 5.15, z, 0.08, 2.2, 0.1, DARK)
				wiper.CFrame *= rake * CFrame.Angles(math.rad(18), 0, 0)
			end
			for _, z in { -3, 3 } do
				p("CabLampHousing", side * 68.49, 2.02, z, 0.22, 1.04, 1.28, DARK)
				cylinder("CabLight", side * 68.65, 2.02, z, 0.14, 0.7, if side > 0 then rgb(255, 233, 171) else RED).Material = M.Neon
			end
			p("CabBumper", side * 68.62, 0.45, 0, 0.55, 0.56, 7.8, DARK)
			p("CabBumperTrim", side * 68.92, 0.5, 0, 0.08, 0.12, 7.2, BRASS)
			p("CabCoupler", side * 69.4, -0.45, 0, 1.5, 0.5, 0.9, DARK)
			p("DriverConsole", side * 67.3, 2.72, 0, 1, 0.7, 6.4, DARK)
			p("DriverControls", side * 67.1, 3.1, 0, 0.45, 0.08, 3.6, STEEL)
			p("DriverSeat", side * 64.8, 1.85, 0, 1.65, 0.45, 1.8, RED, M.Fabric)
			p("DriverSeatBack", side * 64.1, 2.8, 0, 0.35, 1.8, 1.72, RED, M.Fabric)
		end
	end
	model.WorldPivot = dock
	-- Cache the finished geometry (including rotated wheels). A moving train
	-- gets one engine call, and parked trains only move their sliding doors.
	local parts, closed, frames, doorParts, doorFrames = {}, {}, {}, {}, {}
	local doorIndices = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			table.insert(closed, dock:ToObjectSpace(part.CFrame))
			doorIndices[part] = #parts
		end
	end
	for index, door in doors do
		doorParts[index] = door.part
	end
	-- Key by the caller's door list, which the cache itself never retains.
	-- Dropping a streamed-out train also releases its cached part references.
	poses[doors] = {
		parts = parts, closed = closed, frames = frames,
		doorParts = doorParts, doorFrames = doorFrames, doorIndices = doorIndices,
		frame = dock, open = 0,
	}
	model.Parent = parent
	return model, doors
end

function Train.pose(model, doors, frame, open)
	local pose = poses[doors]
	if pose.frame == frame and pose.open == open then return end
	local moving = pose.frame ~= frame
	local parts, frames = pose.doorParts, pose.doorFrames
	if moving then
		parts, frames = pose.parts, pose.frames
		for index, closed in pose.closed do
			frames[index] = frame * closed
		end
	end
	for index, door in doors do
		local target = if moving then pose.doorIndices[door.part] else index
		frames[target] = frame * door.closed * CFrame.new(door.direction * open * 2.7, 0, 0)
	end
	debug.profilebegin("Metro/Pose")
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	debug.profileend()
	model.WorldPivot = frame
	pose.frame, pose.open = frame, open
end

return Train
