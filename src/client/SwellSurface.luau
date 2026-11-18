-- A local water sheet shaped by the same swell field the boats ride. Terrain water
-- stays flat, so without it a hull on a crest hovered studs above the visible sea.
-- The sheet shows the crests; its troughs fade out beneath Terrain's surface.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)
local MeshFeatures = require(ReplicatedStorage.Shared.MeshFeatures)
local WaterQuality = require(script.Parent.WaterQuality)
local EditableMeshBudget = require(script.Parent.EditableMeshBudget)
local TerrainProbe = require(script.Parent.TerrainProbe)

local SwellSurface = {}
-- World-fixed vertex grid around the camera: COUNT cells of SPACING studs a side.
local SPACING = 12
local COUNT = 44
local HALF = COUNT * SPACING / 2
-- Heights ease to zero over this band at the sheet's edge, meeting flat Terrain.
local EDGE_FADE = 72
-- Wet probes are redone this often (streamed shoreline), a few per frame. Each is a
-- 600-stud ray: a 2 s sweep of the 49x49 cells cast ~1200 a second, and a slow frame
-- caught up in one burst of thousands.
local WATER_CHECK_INTERVAL = 5
local SWEEP_PROBES_PER_FRAME = 12
local FIRST_PROBES_PER_FRAME = 40
-- Wind changes over kilometres; vertex amplitudes refresh this often.
local AMPLITUDE_REFRESH = 0.5
local AMPLITUDE_REFRESHES_PER_FRAME = 200
-- Neighbour cells sampled for the shoreline taper (a 5x5 block).
local SHORE_REACH = 2
-- Crests fade in above Terrain's ripples instead of fighting its surface. FADE_FROM sits above
-- Terrain's largest ripple (WaterWaves' MAX_RIPPLE_SIZE, 0.18).
local FADE_FROM, FADE_HEIGHT = 0.22, 0.35
-- Clearance kept beneath a hull's sole so open decks never flood.
local HULL_CLEARANCE = 0.3
local HULL_MARGIN = 1.5
-- Hull boxes are rigid with the root; GetBoundingBox walks every part, so it is
-- redone this often rather than every frame for every boat in range.
local HULL_BOX_REFRESH = 2
-- Vertices within this many cells of the centre update every frame: everywhere the swell is
-- at full strength, so hulls always sit on the exact surface. Only the EDGE_FADE rim, where
-- heights already ease to zero, alternates frames.
local INNER_RING = (HALF - EDGE_FADE) // SPACING
local started = false

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function key(x: number, z: number): number
	return (x + 32768) * 65536 + z + 32768
end

function SwellSurface.start()
	if started then
		return
	end
	started = true
	if not MeshFeatures.EditableMeshesEnabled then
		return
	end
	task.spawn(function()
		local terrain = workspace.Terrain
		local size = COUNT + 1
		local mesh = EditableMeshBudget.create()
		if not mesh then
			warn(
				"[SwellSurface] Water surface unavailable: EditableMesh is disabled or the device mesh budget is exhausted."
			)
			return
		end
		-- Register before CreateMeshPartAsync yields. Fish may claim the budget
		-- while that call is still running; its late result must not revive water.
		local stepped: RBXScriptConnection? = nil
		local surface: MeshPart? = nil
		local released = false
		local function release()
			if released then
				return
			end
			released = true
			if stepped then
				stepped:Disconnect()
			end
			if surface then
				surface:Destroy()
			end
			mesh:Destroy()
		end
		local unregister = EditableMeshBudget.onRelease("SwellSurface", function()
			release()
			warn("[SwellSurface] Water surface released to free EditableMesh memory for fish skins.")
		end)
		local vertices, normals, colors =
			table.create(size * size), table.create(size * size), table.create(size * size)
		local color = terrain.WaterColor
		for row = 0, COUNT do
			for column = 0, COUNT do
				local index = row * size + column + 1
				-- Opposite corners span the vertical range so the part's bounds are
				-- centered and never flat; every frame rewrites the heights anyway.
				local y = if index == 1 then 1 elseif index == size * size then -1 else 0
				vertices[index] = mesh:AddVertex(Vector3.new(column * SPACING - HALF, y, row * SPACING - HALF))
				normals[index] = mesh:AddNormal(Vector3.yAxis)
				colors[index] = mesh:AddColor(color, 0)
			end
		end
		local function face(a: number, b: number, c: number): number
			local id = mesh:AddTriangle(vertices[a], vertices[b], vertices[c])
			mesh:SetFaceNormals(id, { normals[a], normals[b], normals[c] })
			mesh:SetFaceColors(id, { colors[a], colors[b], colors[c] })
			return id
		end
		-- Each triangle is drawn only while all three corners are visible crest (see the cull
		-- after the vertex pass). Vertex alpha alone doesn't hide geometry: hidden stretches of
		-- the sheet lay on or just under Terrain's water and z-fought it in blotches, and could be
		-- seen through it as faceted 12-stud triangles.
		local faceA, faceB, faceC, faceIds = {}, {}, {}, {}
		local function addCorners(a: number, b: number, c: number)
			table.insert(faceA, a)
			table.insert(faceB, b)
			table.insert(faceC, c)
			table.insert(faceIds, face(a, b, c))
		end
		for row = 0, COUNT - 1 do
			for column = 0, COUNT - 1 do
				local a = row * size + column + 1
				local b, c, d = a + 1, a + size, a + size + 1
				-- Counter-clockwise seen from above.
				addCorners(a, c, b)
				addCorners(b, c, d)
			end
		end
		local faceCount = #faceA
		local partOk, part = pcall(function()
			return AssetService:CreateMeshPartAsync(
				Content.fromObject(mesh),
				{ CollisionFidelity = Enum.CollisionFidelity.Box }
			)
		end)
		if released then
			if partOk and part then
				part:Destroy()
			end
			return
		end
		if not partOk or not part then
			unregister()
			release()
			warn("[SwellSurface] Water surface unavailable: could not create its mesh part: " .. tostring(part))
			return
		end
		surface = part
		part.Name = "WeatherSwellSurface"
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Reflectance = 0.08
		-- Let submerged scenery remain visible through the extra crest layer.
		part.Transparency = 0.55
		part.LocalTransparencyModifier = 1
		part.Parent = workspace

		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.IgnoreWater = false
		local function refreshFilter()
			local excluded: { Instance } = { part, workspace.Terrain }
			for _, player in Players:GetPlayers() do
				if player.Character then
					table.insert(excluded, player.Character)
				end
			end
			local boats = workspace:FindFirstChild("PlayerBoats")
			if boats then
				table.insert(excluded, boats)
			end
			parameters.FilterDescendantsInstances = excluded
		end
		-- Terrain comes from voxels: a terrain ray builds collision for every chunk it
		-- crosses that this client never queried (RaycastTerrain > buildKDTree, ~100 ms
		-- frames). The ray, with Terrain excluded, only looks for piers and island meshes
		-- above the surface.
		local function isWater(x: number, z: number): boolean
			if not TerrainProbe.isWater(x, z) then
				return false
			end
			return workspace:Raycast(Vector3.new(x, Biomes.WaterLevel + 512, z), Vector3.new(0, -512, 0), parameters)
				== nil
		end

		-- World grid cells, kept while inside the sheet: wet probe and swell strength.
		local cells = {}
		local alphas = table.create(size * size, -1)
		local caps = {}
		local hullBoxes: { [Model]: { root: BasePart, offset: CFrame, extents: Vector3, at: number } } =
			setmetatable({}, { __mode = "k" }) :: any
		local function hullBox(boat: Model): (CFrame, Vector3)
			local root = boat.PrimaryPart
			if not root then
				return boat:GetBoundingBox()
			end
			local clock = os.clock()
			local cached = hullBoxes[boat]
			if not cached or cached.root ~= root or clock - cached.at > HULL_BOX_REFRESH then
				local frame, extents = boat:GetBoundingBox()
				cached = { root = root, offset = root.CFrame:ToObjectSpace(frame), extents = extents, at = clock }
				hullBoxes[boat] = cached
			end
			return root.CFrame * cached.offset, cached.extents
		end
		-- Per-vertex data that never changes: local X/Z, the edge fade, and whether the vertex
		-- is in the inner ring that updates every frame. Vertices in the fading rim (over
		-- 190 studs out, already easing to flat) update on alternate frames in a checkerboard,
		-- which halves their mesh writes.
		local localX, localZ, edges, inner =
			table.create(size * size), table.create(size * size), table.create(size * size), table.create(size * size)
		for row = 0, COUNT do
			local edgeZ = HALF - math.abs(row * SPACING - HALF)
			for column = 0, COUNT do
				local index = row * size + column + 1
				localX[index], localZ[index] = column * SPACING - HALF, row * SPACING - HALF
				edges[index] = smoothstep(math.min(edgeZ, HALF - math.abs(column * SPACING - HALF)) / EDGE_FADE)
				inner[index] = math.max(math.abs(row - COUNT / 2), math.abs(column - COUNT / 2)) <= INNER_RING
			end
		end
		-- The grid cell under each vertex, rebuilt only when the sheet moves.
		local cellOf = table.create(size * size)
		local frameParity = 0
		local originX, originZ = math.huge, math.huge
		local probeCursor, probeDue = 0, 0
		local refreshCursor, refreshDue = 0, 0
		local coloredAt = -math.huge
		local span = COUNT + 1 + SHORE_REACH * 2
		local freshCursor = 0
		local function cellAt(x: number, z: number)
			local k = key(x, z)
			local cell = cells[k]
			if not cell then
				cell = { x = x, z = z, wet = nil :: boolean?, shoreDirty = false, amplitude = 0, shore = 0, shown = 0 }
				cells[k] = cell
			end
			return cell
		end
		local function probe(cell)
			local water = isWater(cell.x * SPACING, cell.z * SPACING)
			local changed = water ~= (cell.wet == true)
			cell.wet = water
			if not changed then return end
			for dz = -SHORE_REACH, SHORE_REACH do
				for dx = -SHORE_REACH, SHORE_REACH do
					local neighbour = cells[key(cell.x + dx, cell.z + dz)]
					if neighbour then neighbour.shoreDirty = true end
				end
			end
		end
		local function refresh(cell, state)
			if cell.shoreDirty then
				cell.shoreDirty = false
				local wet = 0
				if cell.wet then
					for dz = -SHORE_REACH, SHORE_REACH do
						for dx = -SHORE_REACH, SHORE_REACH do
							local neighbour = cells[key(cell.x + dx, cell.z + dz)]
							if neighbour and neighbour.wet then wet += 1 end
						end
					end
				end
				-- Swells die out before the beach, so the sheet never covers sand.
				cell.shore = smoothstep((wet / (2 * SHORE_REACH + 1) ^ 2 - 0.6) / 0.4)
			end
			cell.amplitude = if cell.wet then Weather.amplitudeAt(
				Vector3.new(cell.x * SPACING, Biomes.WaterLevel, cell.z * SPACING), state
			) else 0
		end

		if released then
			return
		end
		stepped = RunService.RenderStepped:Connect(function(dt: number)
			local camera = workspace.CurrentCamera
			local cameraPosition = camera and camera.CFrame.Position
			if
				not WaterQuality.layeredEnabled()
				or not cameraPosition
				or cameraPosition.Y < Biomes.WaterLevel - 0.5
				or cameraPosition.Y > Biomes.WaterLevel + 180
				or not Biomes.inOceanBounds(cameraPosition)
			then
				if part.LocalTransparencyModifier ~= 1 then part.LocalTransparencyModifier = 1 end
				return
			end
			if part.LocalTransparencyModifier ~= 0 then
				part.LocalTransparencyModifier = 0
			end
			local now = workspace:GetServerTimeNow()
			local state = Weather.getState(now)
			local centerX = math.round(cameraPosition.X / SPACING)
			local centerZ = math.round(cameraPosition.Z / SPACING)
			local firstX, firstZ = centerX - COUNT / 2, centerZ - COUNT / 2
			local moved = false
			if firstX ~= originX or firstZ ~= originZ then
				originX, originZ = firstX, firstZ
				-- The part just moved a cell: every vertex must be rewritten this frame.
				moved = true
				freshCursor = 0
				part.CFrame = CFrame.new(centerX * SPACING, Biomes.WaterLevel, centerZ * SPACING)
				-- Forget cells the sheet left; keep a shore-reach border for the taper.
				for k, cell in cells do
					if
						cell.x < firstX - SHORE_REACH
						or cell.x > firstX + COUNT + SHORE_REACH
						or cell.z < firstZ - SHORE_REACH
						or cell.z > firstZ + COUNT + SHORE_REACH
					then
						cells[k] = nil
					end
				end
			end
			if now - coloredAt >= 2 then
				coloredAt = now
				local water = terrain.WaterColor:Lerp(Color3.fromRGB(160, 205, 210), 0.18)
				if water ~= color then
					color = water
					part.Color = water
					for index = 1, size * size do
						mesh:SetColor(colors[index], water)
					end
				end
			end

			-- Wet probes: unknown cells first (teleport, new rows), then a slow sweep.
			local filtered = false
			local fresh = 0
			while freshCursor < span * span and fresh < FIRST_PROBES_PER_FRAME do
				local row, column = freshCursor // span - SHORE_REACH, freshCursor % span - SHORE_REACH
				freshCursor += 1
				local cell = cellAt(firstX + column, firstZ + row)
				if cell.wet == nil then
					if not filtered then
						filtered = true
						refreshFilter()
					end
					probe(cell)
					refresh(cell, state)
					fresh += 1
				end
			end
			probeDue = math.min(probeDue + span * span * dt / WATER_CHECK_INTERVAL, SWEEP_PROBES_PER_FRAME)
			while probeDue >= 1 do
				probeDue -= 1
				probeCursor = probeCursor % (span * span) + 1
				local row, column = (probeCursor - 1) // span - SHORE_REACH, (probeCursor - 1) % span - SHORE_REACH
				local cell = cellAt(firstX + column, firstZ + row)
				if not filtered then
					filtered = true
					refreshFilter()
				end
				probe(cell)
			end
			refreshDue = math.min(refreshDue + size * size * dt / AMPLITUDE_REFRESH, AMPLITUDE_REFRESHES_PER_FRAME)
			while refreshDue >= 1 do
				refreshDue -= 1
				refreshCursor = refreshCursor % (size * size) + 1
				local row, column = (refreshCursor - 1) // size, (refreshCursor - 1) % size
				refresh(cellAt(firstX + column, firstZ + row), state)
			end

			-- Each nearby hull caps the water inside its footprint below its sole.
			table.clear(caps)
			local boats = workspace:FindFirstChild("PlayerBoats")
			if boats then
				for _, boat in boats:GetChildren() do
					if not boat:IsA("Model") then
						continue
					end
					local frame, extents = hullBox(boat)
					local reach = extents.Magnitude / 2 + HULL_MARGIN
					if (frame.Position - cameraPosition).Magnitude > HALF * 1.5 + reach then
						continue
					end
					local sole = frame.Position.Y - extents.Y / 2 + 0.5
					local root = boat.PrimaryPart
					local floor, offset = boat:GetAttribute("DryFloorHeight"), boat:GetAttribute("WaterlineRootOffset")
					if root and type(floor) == "number" and typeof(offset) == "Vector3" then
						local pose = root.CFrame
						local center = pose:PointToWorldSpace(Vector3.new(0, floor, 0) - offset)
						sole = center.Y
							- math.abs(pose.RightVector.Y) * (boat:GetAttribute("DryFloorHalfBeam") or 0)
							- math.abs(pose.LookVector.Y) * (boat:GetAttribute("DryFloorHalfLength") or 0)
					end
					local cap = sole - HULL_CLEARANCE - Biomes.WaterLevel
					local halfX, halfZ = extents.X / 2 + HULL_MARGIN, extents.Z / 2 + HULL_MARGIN
					local fromX = math.max(0, math.floor((frame.Position.X - reach) / SPACING) - firstX)
					local toX = math.min(COUNT, math.ceil((frame.Position.X + reach) / SPACING) - firstX)
					local fromZ = math.max(0, math.floor((frame.Position.Z - reach) / SPACING) - firstZ)
					local toZ = math.min(COUNT, math.ceil((frame.Position.Z + reach) / SPACING) - firstZ)
					for row = fromZ, toZ do
						for column = fromX, toX do
							local point =
								Vector3.new((firstX + column) * SPACING, frame.Position.Y, (firstZ + row) * SPACING)
							local relative = frame:PointToObjectSpace(point)
							if math.abs(relative.X) <= halfX and math.abs(relative.Z) <= halfZ then
								local index = row * size + column + 1
								caps[index] = math.min(caps[index] or math.huge, cap)
							end
						end
					end
				end
			end

			local profiling = debug.profilebegin ~= nil -- absent in test runners
			if profiling then
				debug.profilebegin("SwellSurface/Vertices")
			end
			if cellOf[1] == nil or cellOf[1].x ~= firstX or cellOf[1].z ~= firstZ then
				for row = 0, COUNT do
					for column = 0, COUNT do
						cellOf[row * size + column + 1] = cellAt(firstX + column, firstZ + row)
					end
				end
			end
			frameParity = 1 - frameParity
			local direction = state.windDirection
			local ease = 1 - math.exp(-dt * 4)
			-- Outer vertices skip every other frame, so they ease by two frames' worth.
			local outerEase = 1 - math.exp(-dt * 8)
			for row = 0, COUNT do
				for column = 0, COUNT do
					local index = row * size + column + 1
					local cell = cellOf[index]
					if not inner[index] and not moved then
						if (row + column) % 2 ~= frameParity then
							continue
						end
						cell.shown += (cell.shore - cell.shown) * outerEase
					else
						cell.shown += (cell.shore - cell.shown) * ease
					end
					local amplitude = cell.amplitude * cell.shown * edges[index]
					local alpha = 0
					if amplitude > FADE_FROM and cell.shown >= 0.01 then
						local unit, sx, sz = Weather.swell(cell.x * SPACING, cell.z * SPACING, now, direction)
						local height = math.min(unit * amplitude, caps[index] or math.huge)
						alpha = smoothstep((height - FADE_FROM) / FADE_HEIGHT)
						-- A hidden vertex is never drawn by the face pass. Leave its mesh storage
						-- alone until it rises into a crest again, even when the sheet recenters.
						if alpha > 0 then
							mesh:SetPosition(vertices[index], Vector3.new(localX[index], height, localZ[index]))
							mesh:SetNormal(normals[index], Vector3.new(-amplitude * sx, 1, -amplitude * sz).Unit)
						end
					end
					if math.abs(alpha - alphas[index]) > 0.02 or (alpha == 0) ~= (alphas[index] == 0) then
						alphas[index] = alpha
						mesh:SetColorAlpha(colors[index], alpha)
					end
				end
			end
			-- Only triangles lying wholly on visible crest (every corner above FADE_FROM) are kept,
			-- so nothing of the sheet is drawn in the band Terrain's surface moves through.
			for f = 1, faceCount do
				local a, b, c = faceA[f], faceB[f], faceC[f]
				local show = alphas[a] > 0 and alphas[b] > 0 and alphas[c] > 0
				local id = faceIds[f]
				if show then
					if not id then
						faceIds[f] = face(a, b, c)
					end
				elseif id then
					mesh:RemoveFace(id)
					faceIds[f] = nil
				end
			end
			if profiling then
				debug.profileend()
			end
		end)
	end)
end

return SwellSurface
