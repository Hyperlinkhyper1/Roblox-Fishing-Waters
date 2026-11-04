-- Three walk-through cars. The server builds a small invisible collision hull;
-- clients build the detailed body and animate it from MetroSchedule without replication spam.
local Train = {}
local V, rgb, M = Vector3.new, Color3.fromRGB, Enum.Material
local CREAM, TEAL = rgb(239, 231, 209), rgb(35, 88, 81)
local DARK, RED = rgb(29, 38, 40), rgb(152, 62, 44)
local poses = setmetatable({}, { __mode = "k" })

function Train.build(parent, dock, collisionOnly)
	local model = Instance.new("Model")
	model.Name = if collisionOnly then "TrainCollision" else "LineOneTrain"
	model:SetAttribute("LodSkip", true)
	local doors = {}
	local function p(name, x, y, z, w, h, d, color, material, solid)
		local part = Instance.new("Part")
		part.Name, part.Size = name, V(w, h, d)
		part.CFrame = dock * CFrame.new(x, y, z)
		part.Anchored, part.CanTouch = true, false
		part.CanCollide = collisionOnly and solid == true
		part.CanQuery = collisionOnly
		part.Color, part.Material = color or CREAM, material or M.Metal
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Transparency = if collisionOnly then 1 else 0
		part.CastShadow = not collisionOnly
		part.Parent = model
		return part
	end
	local function label(part, words, face)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.PixelsPerStud = face or Enum.NormalId.Front, 32
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = part
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		text.Text, text.TextColor3, text.TextScaled = words, CREAM, true
		text.Font, text.Parent = Enum.Font.GothamMedium, gui
	end
	for _, cx in { -46, 0, 46 } do
		p("CarriageFloor", cx, -0.35, 0, 44, 0.7, 10, DARK, M.Metal, true)
		p("CarriageRoof", cx, 9.4, 0, 44.6, 0.8, 10.6, TEAL, M.Metal, true)
		for _, side in { -1, 1 } do
			local z = side * 5
			-- Solid wall runs stop at the two real door openings.
			for _, run in { { -22, -13.8 }, { -8.2, 8.2 }, { 13.8, 22 } } do
				local x, width = cx + (run[1] + run[2]) / 2, run[2] - run[1]
				p("LowerBody", x, 1.7, z, width, 3.4, 0.35, TEAL, M.Metal, true)
				local window = p("WindowGlass", x, 5.45, z, width, 4.1, 0.28, rgb(75, 112, 118), M.Glass, true)
				if not collisionOnly then window.Transparency = 0.38 end
			end
			p("UpperBody", cx, 8.4, z, 44, 1.8, 0.4, CREAM, M.Metal, true)
			for _, dx in { -11, 11 } do
				-- Meet the floor edge without laying a second face over its top.
				p("DoorThreshold", cx + dx, -0.18, side * 5.65, 5.6, 0.36, 1.3, DARK, M.Metal, true)
				for _, half in { -1, 1 } do
					local door = p("SlidingDoor", cx + dx + half * 1.4, 3.8, z - side * 0.15, 2.76, 7.6, 0.3, RED, M.Metal, true)
					table.insert(doors, { part = door, closed = dock:ToObjectSpace(door.CFrame), direction = half })
					if not collisionOnly then
						local glass = p("DoorWindow", cx + dx + half * 1.4, 5.15, z + side * 0.04, 1.9, 3.25, 0.14, rgb(52, 82, 88), M.Glass)
						table.insert(doors, { part = glass, closed = dock:ToObjectSpace(glass.CFrame), direction = half })
					end
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
			p("InteriorCeiling", cx, 8.88, 0, 42, 0.18, 9.3, CREAM)
			p("CeilingLight", cx, 8.74, 0, 36, 0.12, 0.55, rgb(255, 229, 178), M.Neon)
			for _, side in { -1, 1 } do
				for _, dx in { -18, 0, 18 } do
					local width = if dx == 0 then 12 else 5
					p("SeatCushion", cx + dx, 1.9, side * 3.55, width, 0.55, 2, RED, M.Fabric)
					p("SeatBack", cx + dx, 3.175, side * 4.35, width, 2, 0.4, RED, M.Fabric)
					for sx = -width / 2 + 1, width / 2, 2 do
						p("SeatSeam", cx + dx + sx, 1.93, side * 3.55, 0.08, 0.6, 1.95, rgb(125, 47, 37))
					end
				end
				for _, dx in { -7.7, 7.7 } do
					p("GrabPole", cx + dx, 4.4, side * 2.5, 0.15, 8.6, 0.15, rgb(183, 163, 114))
				end
				local route = p("InteriorRouteMap", cx, 7.7, side * 4.73, 11, 0.75, 0.1, TEAL)
				label(route, "1  GULLHAVEN  ──  HAFEN MITTE", if side < 0 then Enum.NormalId.Back else Enum.NormalId.Front)
				for _, dx in { -20, -15, -6, 0, 6, 15, 20 } do
					p("WindowMullion", cx + dx, 5.5, side * 5.2, 0.16, 4.1, 0.12, CREAM)
				end
				p("CoachWaistStripe", cx, 3.5, side * 5.24, 44, 0.16, 0.1, rgb(192, 155, 82))
			end
			for _, dx in { -15.5, 15.5 } do
				p("BogieFrame", cx + dx, -1.55, 0, 7, 1.3, 7.6, DARK)
				for _, axle in { -2, 2 } do
					local wheel = p("WheelAxle", cx + dx + axle, -1.8, 0, 1.9, 1.9, 8.4, DARK)
					wheel.Shape = Enum.PartType.Cylinder
					wheel.Size = V(8.4, 1.9, 1.9)
					wheel.CFrame *= CFrame.Angles(0, math.pi / 2, 0)
				end
			end
			p("RoofVent", cx, 10, 0, 12, 0.5, 4, rgb(103, 117, 113))
		end
	end
	for _, x in { -23, 23 } do
		p("GangwayFloor", x, -0.35, 0, 2, 0.7, 4, DARK, M.Metal, true)
	end
	for _, side in { -1, 1 } do
		p("CabEnd", side * 68, 4.5, 0, 0.4, 9, 10, TEAL, M.Metal, true)
		if not collisionOnly then
			p("CabWindscreen", side * 68.26, 5.7, 0, 0.12, 3.9, 7.6, rgb(35, 54, 60), M.Glass)
			local destination = p("DestinationDisplay", side * 68.3, 8.25, 0, 0.16, 1, 7.5, DARK)
			label(destination, "1  GULLHAVEN ↔ HAFEN MITTE", if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left)
			for _, z in { -3.6, 3.6 } do
				p("CabLight", side * 68.35, 2.15, z, 0.18, 0.7, 0.9, if side > 0 then rgb(255, 233, 171) else RED, M.Neon)
			end
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
