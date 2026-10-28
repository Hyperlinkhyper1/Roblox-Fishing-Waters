-- A local water sheet shaped by the same swell field the boats ride. Terrain water
-- stays flat, so without it a hull on a crest hovered studs above the visible sea.
-- The sheet shows the crests; its troughs fade out beneath Terrain's surface.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

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
-- Crests fade in above Terrain's ripples instead of fighting its surface.
local FADE_FROM, FADE_HEIGHT = 0.05, 0.35
-- Clearance kept beneath a hull's sole so open decks never flood.
local HULL_CLEARANCE = 0.3
local HULL_MARGIN = 1.5
local SUNKEN = -2
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
	task.spawn(function()
		local terrain = workspace.Terrain
		local size = COUNT + 1
		local meshOk, mesh = pcall(function()
			return AssetService:CreateEditableMesh()
		end)
		if not meshOk or not mesh then
			warn(
				"[SwellSurface] Water surface unavailable: EditableMesh is disabled or the device mesh budget is exhausted."
			)
			return
		end
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
		local function face(a: number, b: number, c: number)
			local id = mesh:AddTriangle(vertices[a], vertices[b], vertices[c])
			mesh:SetFaceNormals(id, { normals[a], normals[b], normals[c] })
			mesh:SetFaceColors(id, { colors[a], colors[b], colors[c] })
		end
		for row = 0, COUNT - 1 do
			for column = 0, COUNT - 1 do
				local a = row * size + column + 1
				local b, c, d = a + 1, a + size, a + size + 1
				-- Counter-clockwise seen from above.
				face(a, c, b)
				face(b, c, d)
			end
		end
		local partOk, part = pcall(function()
			return AssetService:CreateMeshPartAsync(
				Content.fromObject(mesh),
				{ CollisionFidelity = Enum.CollisionFidelity.Box }
			)
		end)
		if not partOk or not part then
			mesh:Destroy()
			warn("[SwellSurface] Water surface unavailable: could not create its mesh part: " .. tostring(part))
			return
		end
		part.Name = "WeatherSwellSurface"
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Reflectance = 0.08
		-- Keeps the sheet in the transparent pass, where vertex alpha applies.
		part.Transparency = 0.12
		part.Parent = workspace

		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.IgnoreWater = false
		local function refreshFilter()
			local excluded = { part }
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
		local function isWater(x: number, z: number): boolean
			local hit =
				workspace:Raycast(Vector3.new(x, Biomes.WaterLevel + 512, z), Vector3.new(0, -600, 0), parameters)
			return hit ~= nil and hit.Material == Enum.Material.Water
		end

		-- World grid cells, kept while inside the sheet: wet probe and swell strength.
		local cells = {}
		local alphas = table.create(size * size, -1)
		local originX, originZ = math.huge, math.huge
		local probeCursor, probeDue = 0, 0
		local refreshCursor, refreshDue = 0, 0
		local coloredAt = -math.huge
		local unprobed = true
		local function cellAt(x: number, z: number)
			local k = key(x, z)
			local cell = cells[k]
			if not cell then
				cell = { x = x, z = z, wet = nil :: boolean?, amplitude = 0, shore = 0, shown = 0 }
				cells[k] = cell
			end
			return cell
		end
		local function refresh(cell, now: number, state)
			local wet, total = 0, 0
			for dz = -SHORE_REACH, SHORE_REACH do
				for dx = -SHORE_REACH, SHORE_REACH do
					local neighbour = cells[key(cell.x + dx, cell.z + dz)]
					total += 1
					if neighbour and neighbour.wet then
						wet += 1
					end
				end
			end
			-- Swells die out before the beach, so the sheet never covers sand.
			cell.shore = if cell.wet then smoothstep((wet / total - 0.6) / 0.4) else 0
			local _, amplitude =
				Weather.heightAt(Vector3.new(cell.x * SPACING, Biomes.WaterLevel, cell.z * SPACING), now, state)
			cell.amplitude = amplitude
		end

		RunService.RenderStepped:Connect(function(dt: number)
			local camera = workspace.CurrentCamera
			local cameraPosition = camera and camera.CFrame.Position
			if
				not cameraPosition
				or cameraPosition.Y < Biomes.WaterLevel - 0.5
				or cameraPosition.Y > Biomes.WaterLevel + 180
				or math.abs(cameraPosition.X) > Biomes.MapHalfSize
				or math.abs(cameraPosition.Z) > Biomes.MapHalfSize
			then
				part.LocalTransparencyModifier = 1
				return
			end
			part.LocalTransparencyModifier = 0
			local now = workspace:GetServerTimeNow()
			local state = Weather.getState(now)
			local centerX = math.round(cameraPosition.X / SPACING)
			local centerZ = math.round(cameraPosition.Z / SPACING)
			local firstX, firstZ = centerX - COUNT / 2, centerZ - COUNT / 2
			if firstX ~= originX or firstZ ~= originZ then
				originX, originZ = firstX, firstZ
				unprobed = true
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
			local span = COUNT + 1 + SHORE_REACH * 2
			local filtered = false
			local fresh = 0
			for row = -SHORE_REACH, if unprobed then COUNT + SHORE_REACH else -SHORE_REACH - 1 do
				for column = -SHORE_REACH, COUNT + SHORE_REACH do
					local cell = cellAt(firstX + column, firstZ + row)
					if cell.wet == nil and fresh < FIRST_PROBES_PER_FRAME then
						if not filtered then
							filtered = true
							refreshFilter()
						end
						cell.wet = isWater(cell.x * SPACING, cell.z * SPACING)
						refresh(cell, now, state)
						fresh += 1
					end
				end
			end
			unprobed = fresh >= FIRST_PROBES_PER_FRAME
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
				cell.wet = isWater(cell.x * SPACING, cell.z * SPACING)
			end
			refreshDue = math.min(refreshDue + size * size * dt / AMPLITUDE_REFRESH, AMPLITUDE_REFRESHES_PER_FRAME)
			while refreshDue >= 1 do
				refreshDue -= 1
				refreshCursor = refreshCursor % (size * size) + 1
				local row, column = (refreshCursor - 1) // size, (refreshCursor - 1) % size
				refresh(cellAt(firstX + column, firstZ + row), now, state)
			end

			-- Each nearby hull caps the water inside its footprint below its sole.
			local caps = {}
			local boats = workspace:FindFirstChild("PlayerBoats")
			if boats then
				for _, boat in boats:GetChildren() do
					if not boat:IsA("Model") then
						continue
					end
					local frame, extents = boat:GetBoundingBox()
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

			local direction = state.windDirection
			local ease = 1 - math.exp(-dt * 4)
			for row = 0, COUNT do
				local edgeZ = HALF - math.abs(row * SPACING - HALF)
				for column = 0, COUNT do
					local index = row * size + column + 1
					local cell = cellAt(firstX + column, firstZ + row)
					cell.shown += (cell.shore - cell.shown) * ease
					local edge = smoothstep(math.min(edgeZ, HALF - math.abs(column * SPACING - HALF)) / EDGE_FADE)
					local amplitude = cell.amplitude * cell.shown * edge
					local x, z = cell.x * SPACING, cell.z * SPACING
					local unit, sx, sz = Weather.swell(x, z, now, direction)
					local height = unit * amplitude
					local cap = caps[index]
					if cap and height > cap then
						height = cap
					end
					local alpha = smoothstep((height - FADE_FROM) / FADE_HEIGHT)
					-- Land cells drop out of sight beneath the shore.
					local y = if cell.shown < 0.01 then SUNKEN else height
					mesh:SetPosition(vertices[index], Vector3.new(column * SPACING - HALF, y, row * SPACING - HALF))
					mesh:SetNormal(normals[index], Vector3.new(-amplitude * sx, 1, -amplitude * sz).Unit)
					if math.abs(alpha - alphas[index]) > 0.02 or (alpha == 0) ~= (alphas[index] == 0) then
						alphas[index] = alpha
						mesh:SetColorAlpha(colors[index], alpha)
					end
				end
			end
		end)
	end)
end

return SwellSurface
