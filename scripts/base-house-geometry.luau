-- Production BaseHouse, Props and LowPoly are inserted by check-base-house.cjs.
-- The recording mocks verify real emitted parts and standing clearances;
-- they do not exercise Roblox rendering, Humanoids, replication, or physics.
-- RECORDING_MOCKS --
UDim2.fromOffset = UDim2.new
CFrame.identity = CFrame.new()
local initialInstanceIndex = instanceMt.__index
function instanceMt.__index(self, key)
	local result = initialInstanceIndex(self, key)
	return if result ~= nil then result else self:FindFirstChild(key)
end

local function loadLowPoly()
	-- LOWPOLY_SOURCE --
end
dependencies.LowPoly = loadLowPoly()
local function loadProps()
	-- PROPS_SOURCE --
end
dependencies.Props = loadProps()
local function loadImportedModel()
	-- IMPORTEDMODEL_SOURCE --
end
dependencies.ImportedModel = loadImportedModel()
local function loadShopDeskGeometry()
	-- SHOPDESKGEOMETRY_SOURCE --
end
dependencies.ShopDeskGeometry = loadShopDeskGeometry()
local function loadCashRegisterGeometry()
	-- CASHREGISTERGEOMETRY_SOURCE --
end
dependencies.CashRegisterGeometry = loadCashRegisterGeometry()
local function loadShopDesk()
	-- SHOPDESK_SOURCE --
end
dependencies.ShopDesk = loadShopDesk()
local function loadOfficeDesk()
	-- OFFICEDESK_SOURCE --
end
dependencies.OfficeDesk = loadOfficeDesk()
local function loadFishFreezerGeometry()
	-- FISHFREEZERGEOMETRY_SOURCE --
end
dependencies.FishFreezerGeometry = loadFishFreezerGeometry()
local function loadFishFreezer()
	-- FISHFREEZER_SOURCE --
end
dependencies.FishFreezer = loadFishFreezer()
local function loadBaseGrid()
	-- BASEGRID_SOURCE --
end
dependencies.BaseGrid = loadBaseGrid()
local function loadBaseHouse()
	-- BASEHOUSE_SOURCE --
end
local BaseHouse = loadBaseHouse()
local function loadDiningRoom()
	-- DININGROOM_SOURCE --
end
local DiningRoom = loadDiningRoom()
-- GEOMETRY_HELPERS --

-- WedgeParts have six physical corners; their bounding boxes include an empty
-- top/front corner. Use the actual solid for freezer bounds and clearance.
local boxCorners = corners
corners = function(part, reference)
	if not part:IsA("WedgePart") then
		return boxCorners(part, reference)
	end
	local result = {}
	for _, x in { -0.5, 0.5 } do
		for _, yz in { { -0.5, -0.5 }, { -0.5, 0.5 }, { 0.5, 0.5 } } do
			local p = part.CFrame * Vector3.new(part.Size.X * x, part.Size.Y * yz[1], part.Size.Z * yz[2])
			table.insert(result, if reference then reference:PointToObjectSpace(p) else p)
		end
	end
	return result
end

local checks, routeSamples = 0, 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end

local grid = dependencies.BaseGrid
check(grid.COLUMNS == 11 and grid.ROWS == 7 and grid.CELL_SIZE == 4.5, "Unexpected house grid dimensions")
for column = 1, grid.COLUMNS do
	for row = 1, grid.ROWS do
		local x, z = grid.cellToLocal(column, row)
		local gotColumn, gotRow = grid.localToCell(x, z)
		check(gotColumn == column and gotRow == row, "Grid center did not round trip")
		check(grid.snap(x) == x and grid.snap(z) == z, "Grid center did not snap to itself")
	end
end
check(grid.localToCell(grid.HALF_WIDTH, 0) == nil, "Grid includes its positive outside edge")
check(grid.localToCell(0, -grid.HALF_LENGTH - 0.01) == nil, "Grid includes points outside the house")

local function probe(size, frame)
	local item = Instance.new("Part")
	item.Size, item.CFrame = size, frame
	return item
end

-- The dining extension is built separately when the Restaurant path opens.
-- Its wall centerlines must share the same lattice, with a clear west entrance.
do
	local parent = Instance.new("Model")
	local house = BaseHouse.build(parent, CFrame.identity, Color3.fromRGB(30, 120, 160), 1)
	local room = DiningRoom.build(house, CFrame.identity)
	for _, part in room:GetChildren() do
		if part:IsA("BasePart") then
			if part.Name == "DiningWestWall" or part.Name == "DiningEastWall" then
				check(math.abs((part.Position.X - grid.HALF_WIDTH) / grid.CELL_SIZE - math.round((part.Position.X - grid.HALF_WIDTH) / grid.CELL_SIZE)) < EPS, "Dining side wall is not on a grid border")
			elseif part.Name == "DiningBackWall" then
				check(math.abs((part.Position.Z - grid.HALF_LENGTH) / grid.CELL_SIZE - math.round((part.Position.Z - grid.HALF_LENGTH) / grid.CELL_SIZE)) < EPS, "Dining rear wall is not on a grid border")
			end
		end
	end
	for step = 0, 18 do
		local x = DiningRoom.ARRIVAL.X + (DiningRoom.INSIDE.X - DiningRoom.ARRIVAL.X) * step / 18
		local avatar = probe(Vector3.new(3.9, 5.55, 3.9), CFrame.new(x, 0.16 + 3.225, DiningRoom.DOOR.Z))
		for _, part in room:GetChildren() do
			if part:IsA("BasePart") and part.CanCollide then
				check(not overlaps(avatar, part), "Dining west entrance obstructed by " .. part.Name)
			end
		end
	end
	-- The walk from the street stays between the house wall and the 58-stud
	-- quay edge. Check the full standing envelope against both shells.
	for step = 0, 78 do
		local z = 12 + (DiningRoom.ARRIVAL.Z - 12) * step / 78
		local avatar = probe(Vector3.new(3.9, 5.55, 3.9), CFrame.new(DiningRoom.ARRIVAL.X, 0.16 + 3.225, z))
		for _, group in { house.Shell, room } do
			for _, part in group:GetChildren() do
				if part:IsA("BasePart") and part.CanCollide then
					check(not overlaps(avatar, part), "Dining quay approach obstructed by " .. part.Name)
				end
			end
		end
		check(DiningRoom.ARRIVAL.X - 1.5 >= -29, "Dining approach is not supported by the quay")
	end
end

local function checkLights(house, houseFrame)
	for roomName, area in
		{
			Shop = { -22, 22, grid.SHOP_FRONT + 2, grid.SHOP_BACK - 2, 3 },
			Processing = { -22, 0, -14, 14, 4 },
			Storage = { 4, 22, -14, 14, 4 },
		}
	do
		local lights = house:FindFirstChild(roomName):FindFirstChild("CeilingLights")
		check(lights and #lights:GetChildren() == area[5], "Missing hanging lights in " .. roomName)
		local emitters = {}
		for _, fixture in lights:GetChildren() do
			local mount, cord, bulb = fixture.CeilingMount, fixture.HangingCord, fixture.LampGlobe
			local localMount = houseFrame:PointToObjectSpace(mount.Position)
			check(math.abs(localMount.Y + mount.Size.Y / 2 - 10.875) < 0.01, "Pendant detached from ceiling tie")
			if roomName == "Shop" then
				check(math.min(math.abs(localMount.X), math.abs(math.abs(localMount.X) - 15)) < EPS, "Shop pendant does not align with a ceiling tie")
			else
				check(math.abs(math.abs(localMount.Z) - 10) < EPS, "Pendant does not align with a ceiling tie")
			end
			check(cord.Size.Y > 1 and bulb.Position.Y < mount.Position.Y, "Lamp does not hang below the ceiling")
			for _, piece in fixture:GetChildren() do
				check(piece.Anchored and not piece.CanCollide and not piece.CanQuery, "Hanging light blocks players")
				local low = bounds(piece, houseFrame)
				check(low.Y > 8, "Pendant hangs into avatar headroom")
			end
			local glow = bulb:FindFirstChild("InteriorLight")
			check(glow and glow:IsA("PointLight") and glow.Enabled, "Pendant has no active light")
			check(glow.Brightness > 0 and glow.Brightness <= 0.6, "Interior lighting is excessively bright")
			check(glow.Shadows and glow.Range <= 18, "Interior light can flood the exterior through walls")
			check(bulb.Material ~= Enum.Material.Neon, "Pendant globe adds excessive bloom")
			table.insert(emitters, glow)
		end
		-- Check same-room coverage at floor and standing height. This verifies
		-- range/placement, not rendered brightness or Roblox light attenuation.
		for x = area[1], area[2], 2 do
			for z = area[3], area[4], 2 do
				for _, y in { 0.2, 5 } do
					local sample = houseFrame * Vector3.new(x, y, z)
					local covered = false
					for _, glow in emitters do
						covered = covered or (sample - glow.Parent.Position).Magnitude < glow.Range * 0.9
					end
					check(covered, "Interior lighting range leaves a gap in " .. roomName)
				end
			end
		end
	end
end

local function checkFinish(model, materials)
	for name, material in materials do
		local group = model:FindFirstChild(name)
		check(group and #group:GetChildren() > 0, "Missing finished group " .. name)
		local original = group:GetAttribute("SourceColor")
		for _, part in group:GetChildren() do
			check(part.Material == material, "Missing textured finish: " .. name)
			check(
				math.abs(part.Color.R - original.R)
						+ math.abs(part.Color.G - original.G)
						+ math.abs(part.Color.B - original.B)
					> 0.01,
				"Source placeholder color remains: " .. name
			)
		end
	end
end

local function auditImported(model, geometry, modelFrame, width, sourceName)
	check(model:GetAttribute("SourceModel") == sourceName, "Wrong supplied model: " .. sourceName)
	check(model:GetAttribute("SourceHash") == geometry.sourceHash, "Wrong source bundle: " .. sourceName)
	check(model:GetAttribute("SourceObjectCount") == geometry.sourceObjectCount, "Source object count changed")
	local scale = width / (geometry.boundsMax.X - geometry.boundsMin.X)
	local origin = Vector3.new(
		(geometry.boundsMin.X + geometry.boundsMax.X) / 2,
		(geometry.boundsMin.Y + geometry.boundsMax.Y) / 2,
		geometry.boundsMin.Z
	)
	local function point(v)
		local p = v - origin
		return Vector3.new(p.X, p.Z, -p.Y) * scale
	end
	for _, source in geometry.objects do
		local group = model:FindFirstChild(source.name)
		check(group and #group:GetChildren() > 0, "Missing supplied material group " .. source.name)
		check(group:GetAttribute("SourceFaceCount") == #source.faces, "Source faces were lost")
		local original = group:GetAttribute("SourceColor")
		check(
			original
				and math.abs(original.R - source.color.R) < EPS
				and math.abs(original.G - source.color.G) < EPS
				and math.abs(original.B - source.color.B) < EPS,
			"Original palette metadata was lost"
		)
		local sourceArea, emittedArea, clampedArea, usedVertices, pieces = 0, 0, 0, {}, {}
		for _, face in source.faces do
			local a, b, c =
				point(geometry.vertices[face[1]]), point(geometry.vertices[face[2]]), point(geometry.vertices[face[3]])
			local area = (b - a):Cross(c - a).Magnitude / 2
			sourceArea += area
			if area > 1e-12 then
				for _, vertex in face do
					usedVertices[vertex] = true
				end
			end
		end
		for _, piece in group:GetChildren() do
			check(piece.Transparency == 0, "Source material opacity changed")
			if piece:IsA("WedgePart") then
				emittedArea += piece.Size.Y * piece.Size.Z / 2
				if math.min(piece.Size.Y, piece.Size.Z) <= 0.001000001 then
					clampedArea += piece.Size.Y * piece.Size.Z / 2
				end
			elseif piece.Name == "SurfacePatch" then
				emittedArea += piece.Size.X * piece.Size.Y
			else
				emittedArea += 2 * (piece.Size.X * piece.Size.Y + piece.Size.Y * piece.Size.Z + piece.Size.Z * piece.Size.X)
			end
			table.insert(pieces, {
				frame = modelFrame:ToObjectSpace(piece.CFrame),
				size = piece.Size,
				wedge = piece:IsA("WedgePart"),
				patch = piece.Name == "SurfacePatch",
			})
		end
		check(
			emittedArea >= sourceArea - 0.003 and emittedArea <= sourceArea + 0.003 + clampedArea,
			"Converted surface area changed: " .. source.name .. " source=" .. sourceArea .. " emitted=" .. emittedArea
		)
		-- Coplanar triangles can merge into rectangles. Original vertices must
		-- still lie on the same material's emitted exterior surface.
		for index in usedVertices do
			local p, found = point(geometry.vertices[index]), false
			for _, piece in pieces do
				local q, h = piece.frame:PointToObjectSpace(p), piece.size / 2
				if math.abs(q.X) > h.X + 0.001 or math.abs(q.Y) > h.Y + 0.001 or math.abs(q.Z) > h.Z + 0.001 then
					continue
				end
				if piece.wedge then
					found = q.Y <= piece.size.Y / piece.size.Z * (q.Z + h.Z) - h.Y + 0.001
						and math.abs(math.abs(q.X) - h.X) < 0.001
				elseif piece.patch then
					found = math.abs(q.Z - h.Z) < 0.001
				else
					found = math.min(
						math.abs(math.abs(q.X) - h.X),
						math.abs(math.abs(q.Y) - h.Y),
						math.abs(math.abs(q.Z) - h.Z)
					) < 0.001
				end
				if found then
					break
				end
			end
			check(found, "Supplied vertex moved or was lost: " .. source.name .. "/" .. index)
		end
	end
end

local referenceParts = nil
for index, houseFrame in
	{
		CFrame.new(),
		CFrame.new(123, 8.5, -94) * CFrame.Angles(0, 0.73, 0),
		CFrame.new(-231, 3, 192) * CFrame.Angles(0, -math.pi / 2, 0),
	}
do
	local parent = Instance.new("Model")
	local house = BaseHouse.build(parent, houseFrame, Color3.fromRGB(63, 123, 139), index)
	check(house:GetAttribute("GridColumns") == grid.COLUMNS and house:GetAttribute("GridRows") == grid.ROWS and house:GetAttribute("GridCellSize") == grid.CELL_SIZE, "House grid attributes disagree with shared grid")
	for _, piece in house.Shell:GetChildren() do
		if
			table.find(
				{ "SidePlinth", "EavesBeam", "TimberPost", "DoorJamb", "DoorHeader", "RidgeCap", "CeilingTie" },
				piece.Name
			)
		then
			check(
				not piece.CanCollide and not piece.CanQuery and not piece.CanTouch,
				"House trim still participates in physics"
			)
		end
	end
	check(
		house and house:IsA("Model") and house.Parent == parent,
		"House model must be returned under its requested parent"
	)
	for _, name in { "Shop", "Processing", "Storage", "Shell" } do
		local room = house:FindFirstChild(name)
		check(room and room:IsA("Model"), "Missing house space " .. name)
		check(#room:GetDescendants() > 0, "House space is empty: " .. name)
	end
	for _, gui in house:GetDescendants() do
		if gui:IsA("SurfaceGui") then
			local board = gui.Parent
			check(gui.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize, "House sign lacks an explicit canvas mode")
			check(
				math.abs(gui.CanvasSize.X / gui.CanvasSize.Y - board.Size.X / board.Size.Y) < EPS,
				"House sign canvas stretches the lettering: " .. board.Name
			)
			local label = gui:FindFirstChild("TextLabel")
			check(
				label and label.TextScaled and not label.TextWrapped,
				"House sign must fit its lettering without wrapping"
			)
		end
	end
	-- Rooms retain their floors and receive ceiling lights without extra furniture.
	for roomName, floorName in { Processing = "WashableFloor", Storage = "StoreFloor" } do
		local children = house:FindFirstChild(roomName):GetChildren()
		check(#children == 2 and children[1].Name == floorName, "Unexpected furniture in " .. roomName)
	end
	local shop = house:FindFirstChild("Shop")
	check(#shop:GetChildren() == 3, "Shop must start with its shell, floor and ceiling lights")
	-- The shop is its own building across the road, on the same grid and floor level.
	local shopShell = shop:FindFirstChild("ShopShell")
	check(shopShell and shopShell:IsA("Model") and shop.ShopFloor:IsA("BasePart"), "Shop building lacks its shell or floor")
	local shopFloorLow, shopFloorHigh = bounds(shop.ShopFloor, houseFrame)
	check(math.abs(shopFloorHigh.Y - 0.16) < EPS, "Shop floor is not level with the house floor")
	check(math.abs(shopFloorLow.Z - grid.SHOP_FRONT) < EPS and math.abs(shopFloorHigh.Z - grid.SHOP_BACK) < EPS, "Shop floor does not span its walls")
	check(math.abs(shopFloorLow.X + grid.HALF_WIDTH) < EPS and math.abs(shopFloorHigh.X - grid.HALF_WIDTH) < EPS, "Shop floor is not as wide as the house")
	check(shopShell:FindFirstChild("ShopSign") and not house.Shell:FindFirstChild("ShopSign"), "The owner's shop sign belongs on the shop building")
	for _, part in shopShell:GetChildren() do
		local position = houseFrame:PointToObjectSpace(part.Position)
		if part.Name == "ShopFrontWall" or part.Name == "ShopFrontWallLintel" or part.Name == "ShopFrontWallSillWall" then
			check(math.abs(position.Z - grid.SHOP_FRONT) < EPS, "Shop front wall is not on a grid border")
		elseif part.Name == "ShopBackWall" or part.Name == "ShopBackWallLintel" or part.Name == "ShopBackWallSillWall" then
			check(math.abs(position.Z - grid.SHOP_BACK) < EPS, "Shop back wall is not on a grid border")
		elseif part.Name == "ShopSideWall" then
			check(math.abs(math.abs(position.X) - grid.HALF_WIDTH) < EPS, "Shop side wall is not on a grid border")
		end
	end
	checkLights(house, houseFrame)
	-- The freezer and till are the owner's furniture (FurnitureService); audit them
	-- where every shop starts with them (AnglerData.FIXTURES).
	local freezer = dependencies.FishFreezer.build(shop, dependencies.FishFreezer.frame(houseFrame))
	local desk = dependencies.ShopDesk.build(shop, dependencies.ShopDesk.frame(houseFrame))
	check(desk and desk:IsA("Model"), "Shop is missing its default desk")
	local register = desk:FindFirstChild("CashRegister")
	check(register and register:IsA("Model"), "Desk is missing its cash register")
	checkFinish(desk, {
		obj_0 = Enum.Material.Wood,
		obj_1 = Enum.Material.Wood,
		obj_2 = Enum.Material.Wood,
		obj_3 = Enum.Material.Wood,
		obj_4 = Enum.Material.Metal,
		obj_5 = Enum.Material.Metal,
	})
	checkFinish(register, {
		obj_0_color_2829873 = Enum.Material.Metal,
		obj_0_color_6383466 = Enum.Material.Metal,
		obj_0_color_10988977 = Enum.Material.Metal,
		obj_0_color_14541540 = Enum.Material.SmoothPlastic,
	})
	check(#desk:GetChildren() == 7 and #register:GetChildren() == 4, "Desk/register source groups changed")
	local deskFrame = houseFrame * CFrame.new(-16, 0.16, 70.325) * CFrame.Angles(0, -math.pi / 2, 0)
	local registerFrame = deskFrame * CFrame.new(-2.325, 3, 0)
	local registerLow, registerHigh =
		Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local deskEnd = math.huge
	for _, group in desk:GetChildren() do
		if group == register then
			continue
		end
		for _, part in group:GetChildren() do
			local low, high = bounds(part, houseFrame)
			check(
				low.X >= -17.53 and high.X <= -14.47 and low.Z >= 66.574 and high.Z <= 74.076,
				"Rotated desk is outside its window-wall footprint"
			)
			deskEnd = math.min(deskEnd, low.Z)
			for _, wall in shopShell:GetChildren() do
				if wall:IsA("BasePart") and (wall.Name == "StoneSill" or wall.Name == "ShopFrontWallSillWall") then
					check(not overlaps(part, wall), "Desk clips the window wall or sill")
				end
			end
			check(low.Y >= 0.159 and high.Y <= 3.161, "Desk does not rest on the shop floor")
		end
	end
	check(math.abs(deskEnd - 66.575) < EPS, "Counter end must stand just clear of the window sill")
	for _, part in register:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local low, high = bounds(part, deskFrame)
		registerLow =
			Vector3.new(math.min(registerLow.X, low.X), math.min(registerLow.Y, low.Y), math.min(registerLow.Z, low.Z))
		registerHigh = Vector3.new(
			math.max(registerHigh.X, high.X),
			math.max(registerHigh.Y, high.Y),
			math.max(registerHigh.Z, high.Z)
		)
	end
	check(registerLow.X > -3.75 and registerHigh.X < 0, "Register must sit fully on the left side when facing the desk")
	check(registerLow.Z > -1.5234375 and registerHigh.Z < 1.5234375, "Register overhangs the desktop")
	check(math.abs(registerLow.Y - 3) < 0.011, "Register must rest on top of the desktop without floating or sinking")
	check(registerHigh.Y - registerLow.Y < 2, "Register grew taller than the supplied model")
	check(#register:GetDescendants() < 40, "Cash register is built from too many parts to stream with every base")
	if index == 1 then
		auditImported(desk, dependencies.ShopDeskGeometry, deskFrame, 7.5, "Ingenious Lappi")
	end
	check(freezer and freezer:IsA("Model"), "Shop is missing its default freezer")
	checkFinish(freezer, {
		obj_0 = Enum.Material.SmoothPlastic,
		obj_1 = Enum.Material.Ice,
		obj_2 = Enum.Material.Metal,
		obj_3 = Enum.Material.SmoothPlastic,
		obj_4 = Enum.Material.Fabric,
		obj_5 = Enum.Material.Fabric,
		obj_6 = Enum.Material.SmoothPlastic,
		obj_7 = Enum.Material.Fabric,
		obj_8 = Enum.Material.SmoothPlastic,
		obj_9 = Enum.Material.Fabric,
		obj_10 = Enum.Material.SmoothPlastic,
	})
	check(freezer:GetAttribute("SourceModel") == "Smashing Elzing-Habbi", "Wrong freezer model")
	check(#freezer:GetChildren() == 11, "Freezer lost supplied model objects")
	local sourceFaces = 0
	for _, object in freezer:GetChildren() do
		sourceFaces += object:GetAttribute("SourceFaceCount")
		check(#object:GetChildren() > 0, "Source object is missing its geometry: " .. object.Name)
		for _, part in object:GetChildren() do
			local low, high = bounds(part, houseFrame)
			check(
				low.X >= 17.19 and high.X <= 21.71 and low.Z >= 69.49 and high.Z <= 78.51,
				"Freezer is outside its left-wall footprint"
			)
			check(low.Y >= 0.14 and high.Y < 4.19, "Freezer is not resting on the shop floor")
		end
	end
	check(sourceFaces == 288, "Freezer conversion lost source faces")
	-- A 2 x 1 grid-cell cabinet: 9 wide, 4.5 deep (depth stretched on its own),
	-- its front still at house x = 17.2.
	local freezerFrame = houseFrame * CFrame.new(19.45, 0.16, 74) * CFrame.Angles(0, -math.pi / 2, 0)
	local freezerBounds = dependencies.FishFreezerGeometry
	local depthUnit = 4.5 / (freezerBounds.boundsMax.Y - freezerBounds.boundsMin.Y)
	local originY = (freezerBounds.boundsMin.Y + freezerBounds.boundsMax.Y) / 2
	local function sourcePoint(v)
		return Vector3.new((v.X + 2) * (9 / 150), v.Z * (9 / 150), (originY - v.Y) * depthUnit)
	end
	-- Packaged stock (box objects) rides the stretch rigidly.
	local function rigidPoint(v, center)
		local offset = v - center
		return sourcePoint(center) + Vector3.new(offset.X, offset.Z, -offset.Y) * (9 / 150)
	end
	for _, source in dependencies.FishFreezerGeometry.objects do
		local object = freezer:FindFirstChild(source.name)
		local original = object:GetAttribute("SourceColor")
		check(
			original
				and math.abs(original.R - source.color.R) < EPS
				and math.abs(original.G - source.color.G) < EPS
				and math.abs(original.B - source.color.B) < EPS,
			"Freezer source palette metadata changed"
		)
		local function mapped(vertex)
			return if source.box then rigidPoint(vertex, source.box.center) else sourcePoint(vertex)
		end
		local sourceArea, emittedArea = 0, 0
		for _, face in source.faces do
			local a = mapped(dependencies.FishFreezerGeometry.vertices[face[1]])
			local b = mapped(dependencies.FishFreezerGeometry.vertices[face[2]])
			local c = mapped(dependencies.FishFreezerGeometry.vertices[face[3]])
			sourceArea += (b - a):Cross(c - a).Magnitude / 2
		end
		for _, part in object:GetChildren() do
			check(
				part.Transparency == (if source.name == "obj_0" then 0.58 else 0),
				"Freezer glass or opaque finish changed"
			)
			if part:IsA("WedgePart") then
				emittedArea += part.Size.Y * part.Size.Z / 2
			else
				emittedArea += 2 * (part.Size.X * part.Size.Y + part.Size.Y * part.Size.Z + part.Size.Z * part.Size.X)
			end
		end
		check(math.abs(sourceArea - emittedArea) < 0.002, "Source surface area changed in " .. source.name)
		-- Identity and area alone cannot catch mirrored or misplaced pieces.
		-- Every original vertex must lie on an emitted exterior corner.
		local vertexIndices = {}
		for _, face in source.faces do
			for _, vertexIndex in face do
				vertexIndices[vertexIndex] = true
			end
		end
		local emitted = {}
		for _, part in object:GetChildren() do
			for _, corner in corners(part, freezerFrame) do
				table.insert(emitted, corner)
			end
		end
		for vertexIndex in vertexIndices do
			local expected = mapped(dependencies.FishFreezerGeometry.vertices[vertexIndex])
			local nearest = math.huge
			for _, corner in emitted do
				nearest = math.min(nearest, (corner - expected).Magnitude)
			end
			check(nearest < 0.001, "Source vertex moved or was lost in " .. source.name .. ": " .. vertexIndex)
		end
	end
	check(not house.Shell:FindFirstChild("RoomPartition"), "The house still has the old shop partition")
	local dividerLow, dividerHigh = bounds(house.Shell.StorePartitionFront, houseFrame)
	check(math.abs(dividerHigh.Z - 1.5 * grid.CELL_SIZE) < EPS and dividerLow.Z <= -grid.CELL_SIZE / 2 + EPS, "Storage divider does not meet the lobby back wall")
	local lobbyBackLow, lobbyBackHigh = bounds(house.Shell.LobbyBackWall, houseFrame)
	check(math.abs(lobbyBackLow.X + 1.5 * grid.CELL_SIZE) < EPS and math.abs(lobbyBackHigh.X - 1.5 * grid.CELL_SIZE) < EPS, "Lobby back wall does not enclose the entrance")
	local lobbyFloorLow, lobbyFloorHigh = bounds(house.Shell.LobbyFloor, houseFrame)
	check(math.abs(lobbyFloorLow.X + 1.5 * grid.CELL_SIZE) < EPS and math.abs(lobbyFloorHigh.X - 1.5 * grid.CELL_SIZE) < EPS and math.abs(lobbyFloorLow.Z - 1.5 * grid.CELL_SIZE) < EPS and math.abs(lobbyFloorHigh.Z - grid.HALF_LENGTH) < EPS, "Lobby floor does not cover the enclosed entrance")
	check(house.Shell.LobbyFloor.Material == Enum.Material.WoodPlanks, "Lobby floor does not match the office")
	local _, lobbyRearHigh = bounds(house.Shell.LobbyEastWallRear, houseFrame)
	local lobbyFrontLow = bounds(house.Shell.LobbyEastWallFront, houseFrame)
	check(math.abs(lobbyRearHigh.Z - 2 * grid.CELL_SIZE) < EPS and math.abs(lobbyFrontLow.Z - 3 * grid.CELL_SIZE) < EPS, "Lobby storage doorway is not one grid cell wide")
	local entranceLow, entranceHigh = bounds(house.Shell.EntranceStep, houseFrame)
	check(math.abs(entranceLow.X + entranceHigh.X) < EPS, "Front entrance is not centered on the house")
	local office = house:FindFirstChild("Office")
	check(office and office:FindFirstChild("OfficeFloor"), "Missing enclosed office")
	local officeFloorLow, officeFloorHigh = bounds(office.OfficeFloor, houseFrame)
	local officeBack, officeEast = 0.5 * grid.CELL_SIZE, -1.5 * grid.CELL_SIZE
	check(
		math.abs(officeFloorLow.X + grid.HALF_WIDTH) < EPS
			and math.abs(officeFloorHigh.X - officeEast) < EPS
			and math.abs(officeFloorLow.Z - officeBack) < EPS
			and math.abs(officeFloorHigh.Z - grid.HALF_LENGTH) < EPS,
		"Office floor does not fill the kitchen's front-left corner"
	)
	check(office:FindFirstChild("OfficeSign") and office.OfficeSign:FindFirstChildWhichIsA("SurfaceGui"), "Missing office sign")
	for _, name in { "StorePartitionRear", "StorePartitionFront", "StorePassageLintel" } do
		local divider = house.Shell:FindFirstChild(name)
		check(divider and divider:IsA("BasePart") and divider.CanCollide, "Missing interior wall: " .. name)
	end
	for _, name in { "OfficeBackWall", "OfficeEastWallRear", "OfficeEastWallFront", "OfficeDoorLintel" } do
		local wall = house.Shell:FindFirstChild(name)
		check(wall and wall:IsA("BasePart") and wall.CanCollide, "Missing office wall: " .. name)
	end
	for _, part in house.Shell:GetChildren() do
		if part:IsA("BasePart") then
			local position = houseFrame:PointToObjectSpace(part.Position)
			if part.Name == "RoomPartition" or part.Name == "RoomPartitionLintel" then
				check(math.abs(position.Z - grid.CELL_SIZE / 2) < EPS, "Shop partition is not on a grid border")
			elseif part.Name == "StorePartitionRear" or part.Name == "StorePartitionFront" or part.Name == "StorePassageLintel" then
				check(math.abs(position.X - grid.CELL_SIZE / 2) < EPS, "Rear partition is not on a grid border")
			elseif part.Name == "OfficeBackWall" then
				check(math.abs(position.Z - officeBack) < EPS, "Office back wall is not on a grid border")
			elseif part.Name == "OfficeEastWallRear" or part.Name == "OfficeEastWallFront" or part.Name == "OfficeDoorLintel" then
				check(math.abs(position.X - officeEast) < EPS, "Office east wall is not on a grid border")
			elseif part.Name == "SideWall" then
				check(math.abs(math.abs(position.X) - grid.HALF_WIDTH) < EPS, "Side wall is not on a grid border")
			elseif part.Name == "FrontWall" or part.Name == "RearWall" then
				check(math.abs(math.abs(position.Z) - grid.HALF_LENGTH) < EPS, "End wall is not on a grid border")
			end
		end
	end
	local parts, solid = {}, {}
	for _, item in house:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		table.insert(parts, item)
		check(item.Anchored == true, "House part is unanchored: " .. item:GetFullName())
		for _, axis in { "X", "Y", "Z" } do
			local size = item.Size[axis]
			check(size == size and size > 0 and size < math.huge, "Invalid part size: " .. item:GetFullName())
			local position = item.Position[axis]
			check(
				position == position and math.abs(position) < math.huge,
				"Invalid part position: " .. item:GetFullName()
			)
		end
		if item.CanCollide then
			table.insert(solid, item)
		end
		local low, high = bounds(item, houseFrame)
		check(
			not (item.Transparency < 0.5 and high.X - low.X > 40 and high.Z - low.Z > 24 and low.Y < 7 and high.Y > 1),
			"A full solid building block conceals the interior: " .. item.Name
		)
	end
	check(#parts > 100, "House exterior shell is incomplete")
	check(house.PrimaryPart == house.Processing.WashableFloor, "House primary part must reference its physical kitchen floor")

	local function surfaceAt(x, z)
		local height = -math.huge
		for _, part in solid do
			local low, high = bounds(part, houseFrame)
			if x >= low.X - EPS and x <= high.X + EPS and z >= low.Z - EPS and z <= high.Z + EPS and high.Y <= 0.6 then
				height = math.max(height, high.Y)
			end
		end
		return height
	end
	local function clearRoute(name, points)
		local previousHeight = nil
		for segment = 1, #points - 1 do
			local a, b = points[segment], points[segment + 1]
			local steps = math.max(1, math.ceil((b - a).Magnitude / 0.5))
			for step = 0, steps do
				local p = a:Lerp(b, step / steps)
				local height = surfaceAt(p.X, p.Y)
				check(
					height > -math.huge,
					name .. " has no supporting floor at " .. tostring(p.X) .. ", " .. tostring(p.Y)
				)
				check(not previousHeight or math.abs(height - previousHeight) <= 0.45, name .. " has an oversized step")
				previousHeight = height
				-- Keep 0.45 studs over a low threshold; require a clear standing
				-- envelope three studs wide and six studs high above that.
				local avatar = probe(Vector3.new(3, 5.55, 3), houseFrame * CFrame.new(p.X, height + 3.225, p.Y))
				for _, obstacle in solid do
					check(
						not overlaps(avatar, obstacle),
						name
							.. " blocked by "
							.. obstacle:GetFullName()
							.. " at "
							.. tostring(p.X)
							.. ", "
							.. tostring(p.Y)
					)
				end
				routeSamples += 1
			end
		end
	end
	clearRoute("Front entrance", { Vector2.new(0, 18), Vector2.new(0, 9) })
	clearRoute("Front entrance to kitchen", { Vector2.new(-0.6, 18), Vector2.new(-0.6, 4.5), Vector2.new(-10, 4.5), Vector2.new(-10, -7) })
	clearRoute("Office entrance", { Vector2.new(-2, 11.25), Vector2.new(-10, 11.25) })
	clearRoute("Front entrance to storage", { Vector2.new(3, 18), Vector2.new(3, 9), Vector2.new(6, 7), Vector2.new(13.5, 7), Vector2.new(13.5, -7) })
	clearRoute("Processing to storage", { Vector2.new(-10, -7), Vector2.new(12, -7) })
	-- The shop across the road: the forecourt, its door and the former front-room aisles.
	clearRoute("Forecourt into shop", { Vector2.new(-22.5, 62), Vector2.new(0, 62.4), Vector2.new(0, 70), Vector2.new(0, 78) })
	clearRoute("Forecourt from the right", { Vector2.new(22.5, 62), Vector2.new(0, 62.4) })
	clearRoute("Desk customer aisle", { Vector2.new(-8, 73.5), Vector2.new(-10.5, 73.5), Vector2.new(-10.5, 69) })
	clearRoute("Desk handle side", { Vector2.new(-20.5, 76.75), Vector2.new(-20.5, 69) })
	clearRoute("Freezer customer aisle", { Vector2.new(15, 76.75), Vector2.new(15, 69) })
	clearRoute("Rear entrance", { Vector2.new(-10, -7), Vector2.new(-2.25, -7), Vector2.new(-2.25, -18) })

	if referenceParts then
		check(#parts == #referenceParts, "House transforms change the emitted part count")
		for i, part in parts do
			local original = referenceParts[i]
			check(
				part.Name == original.Name and (part.Size - original.Size).Magnitude < EPS,
				"House transforms change part identity or size"
			)
			local localFrame = houseFrame:ToObjectSpace(part.CFrame)
			check(
				(localFrame.Position - original.CFrame.Position).Magnitude < EPS,
				"Part ignores the house transform: " .. part.Name
			)
			check(
				(localFrame.RightVector - original.CFrame.RightVector).Magnitude < EPS,
				"Part orientation ignores the house transform: " .. part.Name
			)
		end
	else
		referenceParts = parts
	end
	if
		index == 1 and false -- EXPORT_PREVIEW --
	then
		local rows = {}
		local function triple(v)
			return string.format("[%.6f,%.6f,%.6f]", v.X, v.Y, v.Z)
		end
		for _, part in parts do
			local room = part.Parent
			while room.Parent and room.Parent ~= house do
				room = room.Parent
			end
			local vertices = {}
			for _, vertex in corners(part) do
				table.insert(vertices, triple(vertex))
			end
			table.insert(
				rows,
				string.format(
					'{"name":%q,"room":%q,"size":%s,"color":[%.6f,%.6f,%.6f],"transparency":%.6f,"canCollide":%s,"material":%q,"position":%s,"right":%s,"up":%s,"back":%s,"vertices":[%s]}',
					part.Name,
					room.Name,
					triple(part.Size),
					part.Color.R,
					part.Color.G,
					part.Color.B,
					part.Transparency,
					tostring(part.CanCollide),
					tostring(part.Material),
					triple(part.Position),
					triple(part.CFrame.RightVector),
					triple(part.CFrame.UpVector),
					triple(part.CFrame.ZVector),
					table.concat(vertices, ",")
				)
			)
		end
		print("BASE_HOUSE_JSON_BEGIN")
		print('{"source":"Production BaseHouse.build","parts":[' .. table.concat(rows, ",") .. "]}")
		print("BASE_HOUSE_JSON_END")
	end
	print(
		string.format(
			"House %d: %d actual parts; supplied freezer, furnished desk and all connecting routes clear.",
			index,
			#parts
		)
	)
end

local migrations = 0
for _, recoverFrame in { false, true } do
	local dockFrame = CFrame.new(48, 0, -128) * CFrame.Angles(0, 0.73, 0)
	local base = Instance.new("Model")
	base.Name = "Base4"
	base:SetAttribute("BaseId", 4)
	base:SetAttribute("OwnerUserId", 12345)
	if not recoverFrame then
		base:SetAttribute("BoatDockFrame", dockFrame)
	end
	local spawn = probe(Vector3.new(5, 0.2, 5), dockFrame * CFrame.new(4, 6.1, 26))
	spawn._props.ClassName = "SpawnLocation"
	spawn.Name, spawn.Parent = "SpawnPoint", base
	local originalClaimFrame = dockFrame * CFrame.new(-12, 6.05, 26) * CFrame.Angles(0, 0, math.pi / 2)
	local claim = probe(Vector3.new(0.3, 11, 11), originalClaimFrame)
	claim.Name, claim.Shape, claim.Color, claim.Parent =
		"ClaimPad", Enum.PartType.Cylinder, Color3.fromRGB(81, 142, 112), base
	local ring = probe(Vector3.new(0.3, 13, 13), originalClaimFrame + Vector3.new(0, -0.1, 0))
	ring.Name, ring.Shape, ring.Parent = "ClaimRing", Enum.PartType.Cylinder, base
	local originalRingFrame = ring.CFrame
	local unrelatedRing = probe(Vector3.new(0.3, 13, 13), dockFrame * CFrame.new(-20, 6, 26))
	unrelatedRing.Name, unrelatedRing.Shape, unrelatedRing.Parent = "MooringDecoration", Enum.PartType.Cylinder, base
	local unrelatedRingFrame = unrelatedRing.CFrame
	local board = Instance.new("Part")
	board.Name, board.Parent = "NameBoard", base
	local ownerLabel = Instance.new("TextLabel")
	ownerLabel.Text, ownerLabel.Parent = "Captain's Dock", board
	local boatSpawn = probe(Vector3.new(1, 1, 1), dockFrame * CFrame.new(0, 0, -52))
	boatSpawn.Name, boatSpawn.Parent = "BoatSpawn", base
	local marker = probe(Vector3.new(1, 1, 1), dockFrame * CFrame.new(10, 3, -30))
	marker.Name, marker.Parent = "DockMarker", base
	local boatSpawnFrame, markerFrame = boatSpawn.CFrame, marker.CFrame
	base.PrimaryPart = claim
	local oldProps = {}
	for _, name in { "Hut", "FishRack", "Bench" } do
		local old = Instance.new("Model")
		old.Name, old.Parent = name, base
		table.insert(oldProps, old)
	end
	local staleHouse = nil
	if not recoverFrame then
		staleHouse = Instance.new("Model")
		staleHouse.Name, staleHouse.Parent = "BaseHouse", base
		staleHouse:SetAttribute("LayoutVersion", 3)
	end
	BaseHouse.ensure(base)
	local house = base:FindFirstChild("BaseHouse")
	check(house and house:GetAttribute("LayoutVersion") == 13, "Saved base did not receive the current house layout")
	check(not staleHouse or staleHouse.Parent == nil, "Saved base retains a stale house")
	check(
		base:GetAttribute("OwnerUserId") == 12345 and base:GetAttribute("BaseId") == 4,
		"House upgrade changed plot ownership"
	)
	check(board.Parent == base and ownerLabel.Text == "Captain's Dock", "House upgrade changed the owner's name board")
	check(boatSpawn.Parent == base and boatSpawn.CFrame == boatSpawnFrame, "House upgrade changed the boat spawn")
	check(marker.Parent == base and marker.CFrame == markerFrame, "House upgrade changed dock marker geometry")
	check(base.PrimaryPart == claim and claim.Parent == base, "House upgrade replaced the claim pad")
	check(claim.Transparency == 1 and ring.Transparency == 1, "Saved base still shows the claim circle")
	check(not claim.CanCollide and not ring.CanCollide, "Hidden claim circle still blocks players")
	check(unrelatedRing.CFrame == unrelatedRingFrame, "House upgrade moved an unrelated dock cylinder")
	for _, old in oldProps do
		check(old.Parent == nil, "House upgrade retains the old " .. old.Name)
	end
	local recovered = base:GetAttribute("BoatDockFrame")
	check((recovered.Position - dockFrame.Position).Magnitude < EPS, "Saved dock-frame recovery changed plot position")
	check(
		(recovered.LookVector - dockFrame.LookVector).Magnitude < EPS,
		"Saved dock-frame recovery changed plot rotation"
	)
	local expectedHouseFrame = dockFrame * CFrame.new(0, 5.9, 43)
	local actualHouseFrame = house:GetAttribute("HouseFrame")
	check(
		(actualHouseFrame.Position - expectedHouseFrame.Position).Magnitude < EPS,
		"Saved house is misplaced on its plot"
	)
	check(
		(actualHouseFrame.LookVector - expectedHouseFrame.LookVector).Magnitude < EPS,
		"Saved house did not rotate its shop entrance toward the inland path"
	)
	check(
		(spawn.Position - (dockFrame * Vector3.new(4, 6.1, 20))).Magnitude < EPS,
		"Saved spawn did not move onto the clear front apron"
	)
	local expectedClaimPosition = dockFrame * Vector3.new(-12, 6.05, 21)
	check(
		(claim.Position - expectedClaimPosition).Magnitude < EPS,
		"Saved claim pad did not move onto the clear front apron"
	)
	check(
		(claim.CFrame.RightVector - originalClaimFrame.RightVector).Magnitude < EPS,
		"Claim pad lost its cylinder orientation"
	)
	local displacement = expectedClaimPosition - originalClaimFrame.Position
	check(
		(ring.Position - (originalRingFrame.Position + displacement)).Magnitude < EPS,
		"Claim ring did not move together with its pad"
	)
	local afterFirst = #base:GetDescendants()
	local spawnAfterFirst, claimAfterFirst, ringAfterFirst = spawn.CFrame, claim.CFrame, ring.CFrame
	claim.Transparency, ring.Transparency = 0.25, 0
	BaseHouse.ensure(base)
	check(claim.Transparency == 1 and ring.Transparency == 1, "Current house layout retains the claim circle")
	check(
		base:FindFirstChild("BaseHouse") == house and #base:GetDescendants() == afterFirst,
		"House upgrade duplicates a current layout"
	)
	check(
		spawn.CFrame == spawnAfterFirst and claim.CFrame == claimAfterFirst and ring.CFrame == ringAfterFirst,
		"Repeated house upgrade moves existing plot controls"
	)
	-- A map baked with the current shell receives lights and fixtures in place.
	house:SetAttribute("HouseCollisionVersion", nil)
	local savedTrim = house.Shell:FindFirstChild("TimberPost")
	savedTrim.CanCollide, savedTrim.CanQuery, savedTrim.CanTouch = true, true, true
	BaseHouse.ensure(base)
	check(
		base.BaseHouse == house and not savedTrim.CanCollide and not savedTrim.CanQuery and not savedTrim.CanTouch,
		"Saved house trim was not simplified in place"
	)
	local shop = house:FindFirstChild("Shop")
	for _, roomName in { "Shop", "Processing", "Storage" } do
		local lighting = house:FindFirstChild(roomName):FindFirstChild("CeilingLights")
		lighting:Destroy()
	end
	-- Saved maps still hold the old built-in fixtures; they are furniture now.
	local savedDesk = dependencies.ShopDesk.build(shop, dependencies.ShopDesk.frame(actualHouseFrame))
	local savedFreezer = dependencies.FishFreezer.build(shop, dependencies.FishFreezer.frame(actualHouseFrame))
	local savedOfficeDesk = dependencies.OfficeDesk.build(house.Office, dependencies.OfficeDesk.frame(actualHouseFrame))
	BaseHouse.ensure(base)
	check(
		base.BaseHouse == house and savedDesk.Parent == nil and savedFreezer.Parent == nil and savedOfficeDesk.Parent == nil,
		"Saved built-in fixtures were not removed"
	)
	checkLights(house, actualHouseFrame)
	local litCount = #house:GetDescendants()
	local currentLights = shop.CeilingLights
	BaseHouse.ensure(base)
	check(
		shop.CeilingLights == currentLights and #house:GetDescendants() == litCount,
		"Saved lighting upgrade duplicates lamps"
	)
	currentLights:SetAttribute("LayoutVersion", 1)
	BaseHouse.ensure(base)
	check(
		currentLights.Parent == nil and shop.CeilingLights:GetAttribute("LayoutVersion") == 3,
		"Overbright saved lighting was not replaced"
	)
	check(base.BaseHouse == house and #shop:GetChildren() == 3, "Dimming lamps replaced the house")
	checkLights(house, actualHouseFrame)
	migrations += 1
end
local incompleteBase = Instance.new("Model")
local untouchedHut = Instance.new("Model")
untouchedHut.Name, untouchedHut.Parent = "Hut", incompleteBase
BaseHouse.ensure(incompleteBase)
check(
	untouchedHut.Parent == incompleteBase and not incompleteBase:FindFirstChild("BaseHouse"),
	"Incomplete saved base is destructively upgraded without an origin"
)
print(
	string.format(
		"PASS: %d base-house geometry assertions, %d standing-envelope samples, %d saved-map migrations. Roblox rendering and live movement are not exercised.",
		checks,
		routeSamples,
		migrations
	)
)
