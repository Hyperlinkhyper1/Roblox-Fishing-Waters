-- Local, pooled swell ribbons follow the same water samples as the boats.
-- Terrain retains swimming and small ripples; raised, soft crests give the wind
-- waves their visible height without replicating moving geometry to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Weather = require(ReplicatedStorage.Shared.Weather)

local WaterWaves = {}
local GRID = 7
local CELL = 40
local HALF_CREST = 19
local WATER_CHECK_INTERVAL = 0.4
-- Clearance kept around each hull, and the shortest ribbon worth drawing after
-- one is cut back to the side of a boat.
local HULL_MARGIN = 1.5
local MIN_SEGMENT = 6
-- Broad rolling motion rather than rapid oscillation against the land.
local WATER_WAVE_SPEED = 8
local started = false

local function makeBeam(parent: Instance, a: Attachment, b: Attachment, name: string): Beam
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0, beam.Attachment1 = a, b
	beam.FaceCamera = false
	beam.Segments = 8
	beam.CurveSize0, beam.CurveSize1 = HALF_CREST * 2 / 3, HALF_CREST * 2 / 3
	beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.LightEmission = 0
	beam.LightInfluence = 1
	beam.Color =
		ColorSequence.new(if name == "WindSwell" then workspace.Terrain.WaterColor else Color3.fromRGB(205, 229, 230))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.2),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.82, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Enabled = false
	beam.Parent = parent
	return beam
end

-- Horizontal hull footprints near the camera, as ranges on the swell grid's
-- across and along axes. The ribbons lie on the open surface, so without this
-- they draw sea and foam over an open deck that sits below the crests.
local function hullFootprints(cameraPosition: Vector3, across: Vector3, direction: Vector3)
	local footprints = {}
	local boats = workspace:FindFirstChild("PlayerBoats")
	if not boats then
		return footprints
	end
	for _, boat in boats:GetChildren() do
		if not boat:IsA("Model") then
			continue
		end
		local frame, size = boat:GetBoundingBox()
		if (frame.Position - cameraPosition).Magnitude > GRID * CELL + size.Magnitude then
			continue
		end
		local footprint = { acrossMin = math.huge, acrossMax = -math.huge, alongMin = math.huge, alongMax = -math.huge }
		for _, x in { -0.5, 0.5 } do
			for _, z in { -0.5, 0.5 } do
				local corner = frame:PointToWorldSpace(Vector3.new(size.X * x, 0, size.Z * z))
				local u, v = corner:Dot(across), corner:Dot(direction)
				footprint.acrossMin = math.min(footprint.acrossMin, u - HULL_MARGIN)
				footprint.acrossMax = math.max(footprint.acrossMax, u + HULL_MARGIN)
				footprint.alongMin = math.min(footprint.alongMin, v - HULL_MARGIN)
				footprint.alongMax = math.max(footprint.alongMax, v + HULL_MARGIN)
			end
		end
		table.insert(footprints, footprint)
	end
	return footprints
end

-- The part of a ribbon (offsets along `across` from its center) that stays
-- clear of every hull, keeping the longer open side. Nil hides the ribbon.
local function clearSpan(center: Vector3, halfWidth: number, footprints, across: Vector3, direction: Vector3)
	local from, to = -HALF_CREST, HALF_CREST
	local u, v = center:Dot(across), center:Dot(direction)
	for _, footprint in footprints do
		if footprint.alongMin > v + halfWidth or footprint.alongMax < v - halfWidth then
			continue
		end
		local low, high = footprint.acrossMin - u, footprint.acrossMax - u
		if low >= to or high <= from then
			continue
		end
		if low - from >= to - high then
			to = low
		else
			from = high
		end
		if to - from < MIN_SEGMENT then
			return nil
		end
	end
	return from, to
end

local function surfaceFrame(position: Vector3, tangent: Vector3, normal: Vector3): CFrame
	local alongSurface = (tangent - normal * tangent:Dot(normal)).Unit
	return CFrame.fromMatrix(position, alongSurface, normal:Cross(alongSurface).Unit)
end

function WaterWaves.start()
	if started then
		return
	end
	started = true
	local terrain = workspace.Terrain
	local root = Instance.new("Part")
	root.Name = "WeatherWaterWaves"
	root.Size = Vector3.one
	root.Anchored = true
	root.Transparency = 1
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.CastShadow = false
	root.Parent = workspace
	local ribbons = {}
	for row = -(GRID - 1) / 2, (GRID - 1) / 2 do
		for column = -(GRID - 1) / 2, (GRID - 1) / 2 do
			local a, b = Instance.new("Attachment"), Instance.new("Attachment")
			a.Name, b.Name = "SwellStart", "SwellEnd"
			a.Parent, b.Parent = root, root
			table.insert(ribbons, {
				row = row,
				column = column,
				a = a,
				b = b,
				water = false,
				body = makeBeam(root, a, b, "WindSwell"),
				edge = makeBeam(root, a, b, "WindCrest"),
			})
		end
	end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.IgnoreWater = false
	local function isWater(position: Vector3): boolean
		-- Include the island's mesh parts as well as terrain, so water under the
		-- low-poly shore can never receive floating crests over dry land.
		local hit = workspace:Raycast(
			Vector3.new(position.X, Biomes.WaterLevel + 512, position.Z),
			Vector3.new(0, -600, 0),
			parameters
		)
		return hit ~= nil and hit.Material == Enum.Material.Water
	end
	local checkedAt, coloredAt = -math.huge, -math.huge
	local lastCamera: Vector3? = nil
	local lastGrid: Vector3? = nil
	local coastalExposure = 1
	-- Every frame: throttled updates stepped the crests visibly against the camera.
	RunService.Heartbeat:Connect(function(dt: number)
		local step = dt
		local camera = workspace.CurrentCamera
		if not camera then
			for _, ribbon in ribbons do
				ribbon.body.Enabled, ribbon.edge.Enabled = false, false
			end
			return
		end
		local now = workspace:GetServerTimeNow()
		local state = Weather.getState(now)
		local cameraPosition = camera.CFrame.Position
		local _, cameraAmplitude = Weather.heightAt(cameraPosition, now, state)
		-- Let the actual water surface visibly roll, alongside the shared crests.
		-- Exposure still keeps the inner lake much calmer than the open sea.
		local ripple = math.clamp(cameraAmplitude * 1.3 * coastalExposure, 0, 1)
		terrain.WaterWaveSize += (ripple - terrain.WaterWaveSize) * (1 - math.exp(-step * 3))
		-- The engine derives wave phase from elapsed time * speed, so any change in
		-- speed (gusts, coastal exposure) jumps every ripple. Wind shows in the size.
		terrain.WaterWaveSpeed = WATER_WAVE_SPEED
		local direction = Vector3.new(state.windDirection.X, 0, state.windDirection.Z)
		direction = if direction.Magnitude > 0.001 then direction.Unit else Vector3.xAxis
		local across = Vector3.new(-direction.Z, 0, direction.X)
		local projected = Vector3.new(cameraPosition.X, Biomes.WaterLevel, cameraPosition.Z)
		local acrossOrigin = math.floor(projected:Dot(across) / CELL + 0.5) * CELL
		-- World-space rows move continuously with the wind. Recenter by a whole
		-- cell, keeping neighboring pooled crests in the same repeating grid.
		local travel = (now * Weather.components[1].speed) % CELL
		local alongOrigin = math.floor((projected:Dot(direction) - travel) / CELL + 0.5) * CELL + travel
		local gridOrigin = across * acrossOrigin + direction * alongOrigin
		local checkWater = now - checkedAt >= WATER_CHECK_INTERVAL
			or lastCamera == nil
			or (cameraPosition - lastCamera).Magnitude > CELL / 2
			or lastGrid == nil
			or (gridOrigin - lastGrid).Magnitude > CELL / 2
		if checkWater then
			parameters.FilterDescendantsInstances = if Players.LocalPlayer.Character
				then { root, Players.LocalPlayer.Character }
				else { root }
			checkedAt, lastCamera, lastGrid = now, cameraPosition, gridOrigin
			-- Sample the actual coast, including the smaller islands. Breaking waves
			-- settle in the shallows while exposed water retains its larger swells.
			local wet = 0
			for index = 0, 7 do
				local angle = index * math.pi / 4
				if isWater(projected + Vector3.new(math.cos(angle) * 64, 0, math.sin(angle) * 64)) then
					wet += 1
				end
			end
			-- Native ripples repeatedly cut through the land and thin foam sheets.
			-- Remove those at the coast; the shoreward wash supplies its motion.
			-- Only fully exposed viewpoints retain the large native oscillations.
			coastalExposure = math.clamp((wet - 6) / 2, 0, 1) ^ 2
		end
		local recolor = now - coloredAt >= 0.5
		if recolor then
			coloredAt = now
		end
		local footprints = hullFootprints(cameraPosition, across, direction)
		local visible = cameraPosition.Y > Biomes.WaterLevel - 0.5
			and cameraPosition.Y < Biomes.WaterLevel + 180
			and math.abs(cameraPosition.X) < Biomes.MapHalfSize
			and math.abs(cameraPosition.Z) < Biomes.MapHalfSize
		for _, ribbon in ribbons do
			local center = across * (acrossOrigin + ribbon.column * CELL)
				+ direction * (alongOrigin + ribbon.row * CELL)
			local a, b = center - across * HALF_CREST, center + across * HALF_CREST
			local height, amplitude = Weather.heightAt(center, now, state)
			local width = math.clamp(8 + amplitude * 6, 8, 24)
			local from, to = clearSpan(center, width / 2, footprints, across, direction)
			if checkWater and visible then
				ribbon.water = isWater(center)
					and isWater(a)
					and isWater(b)
					and isWater(a + direction * width / 2)
					and isWater(a - direction * width / 2)
					and isWater(b + direction * width / 2)
					and isWater(b - direction * width / 2)
			end
			local crest = math.clamp(height / math.max(amplitude, 0.01), 0, 1)
			local fade = math.clamp((crest - 0.08) / 0.6, 0, 1)
			local enabled = visible and ribbon.water and fade > 0.01 and from ~= nil
			ribbon.body.Enabled, ribbon.edge.Enabled = enabled, enabled
			if not enabled then
				continue
			end
			-- Draw only the stretch clear of hulls; the faded ends keep the cut soft.
			a, b = center + across * from, center + across * to
			local curve = (to - from) / 3
			ribbon.body.CurveSize0, ribbon.body.CurveSize1 = curve, curve
			ribbon.edge.CurveSize0, ribbon.edge.CurveSize1 = curve, curve
			local sampleA, sampleB = Weather.sample(a, now, state), Weather.sample(b, now, state)
			ribbon.a.CFrame =
				surfaceFrame(Vector3.new(a.X, Biomes.WaterLevel + sampleA.height + 0.06, a.Z), across, sampleA.normal)
			ribbon.b.CFrame =
				surfaceFrame(Vector3.new(b.X, Biomes.WaterLevel + sampleB.height + 0.06, b.Z), across, sampleB.normal)
			ribbon.body.Width0, ribbon.body.Width1 = width, width
			ribbon.edge.Width0, ribbon.edge.Width1 = 1.1 + amplitude * 0.9, 0.9 + amplitude * 0.7
			local distanceFade = math.clamp((GRID * CELL * 0.65 - (center - projected).Magnitude) / CELL, 0, 1)
			ribbon.body.LocalTransparencyModifier = 1 - fade * distanceFade * 0.68
			ribbon.edge.LocalTransparencyModifier = 1 - fade * distanceFade * (0.32 + state.rain * 0.48)
			if recolor then
				ribbon.body.Color = ColorSequence.new(terrain.WaterColor:Lerp(Color3.fromRGB(160, 205, 210), 0.32))
				ribbon.edge.Color = ColorSequence.new(Color3.fromRGB(205, 229, 230))
			end
		end
	end)
end

return WaterWaves
