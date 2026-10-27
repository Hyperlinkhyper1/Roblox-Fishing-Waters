-- MOCKS --
Vector3.one = Vector3.new(1, 1, 1)
local RaycastParams = {
	new = function()
		return {}
	end,
}
local renderStep = { callbacks = {} }
function renderStep:Connect(callback)
	table.insert(self.callbacks, callback)
end
function renderStep:Fire(dt)
	for _, callback in self.callbacks do
		callback(dt)
	end
end
local localPlayer = { Character = Instance.new("Model") }
local otherPlayer = { Character = Instance.new("Model") }
game.GetService = function(_, name)
	return if name == "Players"
		then {
			GetPlayers = function()
				return { localPlayer, otherPlayer }
			end,
		}
		elseif name == "RunService" then { RenderStepped = renderStep }
		else {}
end
workspace = Instance.new("Folder")
workspace.Terrain = {
	WaterColor = Color3.fromRGB(30, 80, 96),
	WaterWaveSize = 0.1,
	WaterWaveSpeed = 8,
}
workspace:SetAttribute("WeatherEpoch", 0)
-- A known storm core reaches the open-water camera during this render check.
workspace:SetAttribute("WeatherSeed", 888)
workspace:SetAttribute("WeatherOverride", "Storm")
local now, rays, dry = 1000, 0, false
function workspace:GetServerTimeNow()
	return now
end
function workspace:Raycast(origin, direction, parameters)
	rays += 1
	assert(direction.Y < 0 and not parameters.IgnoreWater, "Water rays must include the surface")
	assert(table.find(parameters.FilterDescendantsInstances, localPlayer.Character), "Local character must be excluded")
	assert(
		table.find(parameters.FilterDescendantsInstances, otherPlayer.Character),
		"Other swimmers must not change the coast mask"
	)
	local boats = workspace:FindFirstChild("PlayerBoats")
	if boats then
		assert(table.find(parameters.FilterDescendantsInstances, boats), "Moving boats must not count as shoreline")
	end
	return { Material = if dry or origin.X < -1000 then Enum.Material.Sand else Enum.Material.Water }
end
local camera = { CFrame = CFrame.new(1500, 12, 0) }
workspace.CurrentCamera = camera
local function loadBiomes()
	-- BIOMES --
end
dependencies.Biomes = loadBiomes()
local function loadWeather()
	-- WEATHER --
end
dependencies.Weather = loadWeather()
local function loadClient()
	-- CLIENT --
end
local Client = loadClient()
local function tick(dt)
	now += dt
	renderStep:Fire(dt)
end
local function beams()
	local result = {}
	for _, item in workspace:GetDescendants() do
		if item:IsA("Beam") then
			table.insert(result, item)
		end
	end
	return result
end
local function enabledCount()
	local total = 0
	for _, beam in beams() do
		if beam.Enabled then
			total += 1
		end
	end
	return total
end
Client.start()
Client.start()
local pool = beams()
assert(#pool > 0 and #pool <= 100 and #renderStep.callbacks == 1, "Startup must keep one bounded render pool")
for _, beam in pool do
	assert(
		beam.TextureSpeed == 0,
		"Crest textures must travel with the geometry without independent sideways scrolling"
	)
end
local motion, previous = false, {}
local maximumSeaHeight = 0
local strongestCrestOpacity = 0
local function assertSurfaceClearance(beam)
	local a, b = beam.Attachment0.CFrame, beam.Attachment1.CFrame
	local p0, p3 = a.Position, b.Position
	local p1 = p0 + a.RightVector * beam.CurveSize0
	local p2 = p3 - b.RightVector * beam.CurveSize1
	for segment = 0, beam.Segments do
		local t = segment / beam.Segments
		local u = 1 - t
		local center = p0 * u ^ 3 + p1 * (3 * u ^ 2 * t) + p2 * (3 * u * t ^ 2) + p3 * t ^ 3
		local side = a.UpVector:Lerp(b.UpVector, t).Unit
		local halfWidth = (beam.Width0 + (beam.Width1 - beam.Width0) * t) / 2
		assert(
			center.Y - math.abs(side.Y) * halfWidth > dependencies.Biomes.WaterLevel + workspace.Terrain.WaterWaveSize,
			"Every visible ribbon segment must clear native water, including its tilted edges"
		)
	end
end
for _ = 1, 120 do
	tick(1 / 30)
	for _, beam in pool do
		if not beam.Enabled then
			continue
		end
		local attachment = beam.Attachment0
		assertSurfaceClearance(beam)
		local position = attachment.CFrame.Position
		if previous[attachment] and (position - previous[attachment]).Magnitude > 0.1 then
			motion = true
		end
		previous[attachment] = position
		local actual = dependencies.Weather.heightAt(position, now, dependencies.Weather.getState(now))
		assert(math.abs(position.Y - actual - 0.06) < 1e-5, "Visible crests must sample the boat's exact wave height")
		maximumSeaHeight = math.max(maximumSeaHeight, position.Y)
		if beam.Name == "WindCrest" then
			strongestCrestOpacity = math.max(strongestCrestOpacity, 1 - beam.LocalTransparencyModifier)
			assert(beam.Width0 > 1, "Crests must be wide enough to read from a boat")
		end
		assert(
			math.abs(attachment.CFrame.RightVector:Dot(attachment.CFrame.UpVector)) < 1e-5,
			"Water ribbons must lie in the sampled surface tangent plane"
		)
	end
end
assert(motion and maximumSeaHeight > 0.3, "Storm crests must visibly move and rise above the sea")
assert(enabledCount() > 0, "Open water must show crests")
local seaRipple = workspace.Terrain.WaterWaveSize
assert(seaRipple > 0.15 and seaRipple <= 0.18, "Native storm ripples must stay small beneath the shared swells")
assert(strongestCrestOpacity > 0.5, "Storm crests must have clearly visible contrast")
local bodyDepth, foamDepth
for _, beam in pool do
	if beam.Name == "WindSwell" then
		bodyDepth = beam.ZOffset
	else
		foamDepth = beam.ZOffset
	end
end
assert(foamDepth > bodyDepth and bodyDepth > 0, "Foam and swell layers must have separate surface depths")
-- Isolate wave strength from phase and the land mask: tiny lake waves should
-- fade away rather than drawing full-contrast foam against the terrain surface.
local realHeightAt = dependencies.Weather.heightAt
local realSample = dependencies.Weather.sample
local testAmplitude = 0.05
dependencies.Weather.heightAt = function()
	return testAmplitude * 0.8, testAmplitude
end
dependencies.Weather.sample = function()
	return { height = testAmplitude * 0.8, normal = Vector3.yAxis }
end
tick(1 / 60)
assert(enabledCount() == 0, "Tiny sheltered waves must not draw intersecting ribbons")
testAmplitude = 0.5
tick(1 / 60)
assert(enabledCount() > 0, "Growing swells must ease into view")
local middleOpacity = 0
for _, beam in pool do
	if beam.Enabled and beam.Name == "WindCrest" then
		middleOpacity = math.max(middleOpacity, 1 - beam.LocalTransparencyModifier)
	end
end
testAmplitude = 1
tick(1 / 60)
local fullOpacity = 0
for _, beam in pool do
	if beam.Enabled and beam.Name == "WindCrest" then
		fullOpacity = math.max(fullOpacity, 1 - beam.LocalTransparencyModifier)
	end
end
assert(middleOpacity > 0 and middleOpacity < fullOpacity * 0.6, "Sheltered foam must blend gradually into sea foam")
-- A positive center is insufficient: ends, tilted widths and cubic handles
-- can each pass through water independently of that center sample.
testAmplitude = 2
dependencies.Weather.sample = function()
	return { height = 0.05, normal = Vector3.yAxis }
end
tick(1 / 60)
assert(enabledCount() == 0, "Positive crest centers must not expose submerged ribbon ends")
local windDirection = dependencies.Weather.getState(now).windDirection
local across = Vector3.new(-windDirection.Z, 0, windDirection.X)
dependencies.Weather.sample = function()
	return { height = 1, normal = (Vector3.yAxis + windDirection * 0.4).Unit }
end
tick(1 / 60)
assert(enabledCount() == 0, "Tilted wide ribbons must fade before their sides enter the water")
dependencies.Weather.sample = function(position)
	local sign = if position:Dot(across) % 40 < 20 then -1 else 1
	return { height = 1, normal = (Vector3.yAxis + across * sign * 0.4).Unit }
end
tick(1 / 60)
assert(enabledCount() == 0, "Cubic handles must not dip beneath otherwise clear endpoints")
dependencies.Weather.sample = function()
	return { height = 2, normal = Vector3.yAxis }
end
tick(1 / 60)
assert(enabledCount() > 0, "Safely raised crests must remain visible")
for _, beam in pool do
	if beam.Enabled then
		assertSurfaceClearance(beam)
	end
end

-- Isolate camera recentering at frozen wave time and strength. Any entering
-- or leaving grid row must already be transparent at the pool boundary.
local function snapshotCrests()
	local snapshot = {}
	for _, beam in pool do
		if beam.Enabled and beam.Name == "WindCrest" then
			local center = (beam.Attachment0.CFrame.Position + beam.Attachment1.CFrame.Position) / 2
			local key = tostring(math.round(center:Dot(across) / 40))
				.. ":"
				.. tostring(
					math.round((center:Dot(windDirection) - now * dependencies.Weather.components[1].speed) / 40)
				)
			snapshot[key] = 1 - beam.LocalTransparencyModifier
		end
	end
	return snapshot
end
local function assertRecenterFade(before, after)
	local common, replaced = 0, 0
	for key, opacity in before do
		if after[key] then
			common += 1
			assert(
				math.abs(opacity - after[key]) < 0.01,
				"Shared crests must remain stable across a camera grid boundary"
			)
		else
			replaced += 1
			assert(opacity < 0.001, "Recycled boundary rows must fade out before disappearing")
		end
	end
	assert(common > 0 and replaced > 0, "Recenter check must exercise both shared and recycled crests")
end
for _, axis in { across, windDirection } do
	local center = Vector3.new(1500, 12, 0)
	local travel = if axis == windDirection then (now * dependencies.Weather.components[1].speed) % 40 else 0
	local boundary = math.floor((center:Dot(axis) - travel) / 40) * 40 + 20 + travel
	center += axis * (boundary - center:Dot(axis))
	camera.CFrame = CFrame.new(center - axis * 0.1)
	-- Masks are probed a few ribbons per frame; let the whole grid settle first.
	for _ = 1, 30 do
		tick(0)
	end
	local before = snapshotCrests()
	camera.CFrame = CFrame.new(center + axis * 0.1)
	tick(0)
	local after = snapshotCrests()
	assertRecenterFade(before, after)
	assertRecenterFade(after, before)
end
camera.CFrame = CFrame.new(1500, 12, 0)
dependencies.Weather.heightAt = realHeightAt
dependencies.Weather.sample = realSample
local FULL_RIBBON_LENGTH = 19 * 2 - 0.5
-- A boat beside the camera: no ribbon may draw inside its hull footprint.
local boats = Instance.new("Folder")
boats.Name = "PlayerBoats"
boats.Parent = workspace
local boat = Instance.new("Model")
boat.Parent = boats
local hullSize = Vector3.new(12, 6, 30)
-- A real hull part, so the boat's bounding box comes from its geometry.
local hull = Instance.new("Part")
hull.Size = hullSize
hull.CFrame = CFrame.new(1500, 2, 0)
hull.Parent = boat
local function insideHull(position)
	return math.abs(position.X - 1500) < hullSize.X / 2 and math.abs(position.Z) < hullSize.Z / 2
end
local cut = false
for _ = 1, 90 do
	tick(1 / 30)
	for _, beam in pool do
		if not beam.Enabled then
			continue
		end
		local a, b = beam.Attachment0.CFrame.Position, beam.Attachment1.CFrame.Position
		if (b - a).Magnitude < FULL_RIBBON_LENGTH then
			cut = true
		end
		for step = 0, 20 do
			assert(not insideHull(a:Lerp(b, step / 20)), "Swell ribbons must not draw inside a boat's hull")
		end
	end
end
assert(cut and enabledCount() > 0, "Ribbons next to a boat must be shortened, not all hidden")
boats.Parent = nil
dry = true
-- Masks are rechecked a few ribbons per frame; give every ribbon its turn.
for _ = 1, 120 do
	tick(1 / 30)
end
assert(enabledCount() == 0, "Dry land must mask all swells")
assert(
	workspace.Terrain.WaterWaveSize < seaRipple * 0.1,
	"Coastal viewpoints must suppress native oscillations that clip through the shoreline"
)
dry = false
for _ = 1, 120 do
	tick(1 / 30)
end
assert(enabledCount() > 0, "Water masks must refresh after geometry changes")
local beforeTeleport = rays
camera.CFrame = CFrame.new(-2000, 12, 0)
tick(0.04)
assert(rays > beforeTeleport and enabledCount() == 0, "Camera teleport must invalidate cached water masks immediately")
workspace.CurrentCamera = nil
tick(0.04)
assert(enabledCount() == 0, "Missing camera must hide every ribbon")
workspace.CurrentCamera = camera
camera.CFrame = CFrame.new(0, 12, 0)
for _ = 1, 120 do
	tick(1 / 30)
end
assert(#beams() == #pool, "Camera recovery must reuse its render pool")
assert(workspace.Terrain.WaterWaveSize > 0, "Camera recovery must resume the sheltered lake's native ripples")
assert(workspace.Terrain.WaterWaveSize < seaRipple * 0.5, "Lake ripples must be smaller than open-sea ripples")
assert(workspace.Terrain.WaterWaveSize < 0.3, "Inner lake must retain sheltered waves")
-- The actual renderer must distinguish every severity, even inside the lake.
for _, position in { Vector3.new(0, 12, 0), Vector3.new(1500, 12, 0) } do
	camera.CFrame = CFrame.new(position)
	local previousRipple, calmRipple = 0, 0
	for _, kind in { "Clear", "LightRain", "Rain", "Storm" } do
		workspace:SetAttribute("WeatherOverride", kind)
		for _ = 1, 120 do
			tick(1 / 30)
		end
		local ripple = workspace.Terrain.WaterWaveSize
		assert(ripple > previousRipple * 1.3, "Each rain severity must visibly strengthen surface ripples")
		if kind == "Clear" then
			calmRipple = ripple
		elseif kind == "Storm" then
			assert(ripple > calmRipple * 5, "Storm water must be substantially rougher than clear water")
		end
		previousRipple = ripple
	end
end
print("PASS wind-driven rain and storm ripples in both the sheltered lake and open sea")
-- Small camera motion at a coastal probe boundary must not pump the entire sea
-- between calm and exposed waves. Hold wind steady to isolate the coast blend.
local weatherState = dependencies.Weather.getState(now)
dependencies.Weather.getState = function()
	return weatherState
end
camera.CFrame = CFrame.new(-936, 12, 0)
for _ = 1, 180 do
	tick(1 / 60)
end
local smallestRipple, largestRipple = math.huge, -math.huge
for frame = 1, 720 do
	camera.CFrame = CFrame.new(-936 + math.sin(frame / 60 * math.pi * 2) * 0.5, 12, 0)
	tick(1 / 60)
	if frame > 180 then
		smallestRipple = math.min(smallestRipple, workspace.Terrain.WaterWaveSize)
		largestRipple = math.max(largestRipple, workspace.Terrain.WaterWaveSize)
	end
	assert(workspace.Terrain.WaterWaveSpeed == 8, "Coast transitions must preserve the native ripple phase")
end
assert(
	largestRipple - smallestRipple < 0.02,
	"Half-stud camera sway at the coast must not make the whole water surface jitter"
)
-- Travel in both directions across coast-sample cells and the real lake mouth.
-- Consecutive frame changes stay small at both low and high refresh rates.
for _, fps in { 30, 144 } do
	for _, reverse in { false, true } do
		local previousRipple = workspace.Terrain.WaterWaveSize
		for frame = 1, fps * 10 do
			local progress = frame / (fps * 10)
			if reverse then
				progress = 1 - progress
			end
			camera.CFrame = CFrame.new(-1020 + progress * 240, 12, 0)
			tick(1 / fps)
			if frame > fps * 2 then
				assert(
					math.abs(workspace.Terrain.WaterWaveSize - previousRipple) < 0.9 / fps,
					"Moving through shoreline blend cells must not step the native waves"
				)
			end
			previousRipple = workspace.Terrain.WaterWaveSize
		end
	end
end
local mouth = Vector3.new(((290 + 430) / 2 - 870) * 0.85, 12, ((1565 + 1340) / 2 - 1330) * 0.85)
for _, reverse in { false, true } do
	local previousRipple = workspace.Terrain.WaterWaveSize
	for frame = 1, 600 do
		local progress = frame / 600
		if reverse then
			progress = 1 - progress
		end
		camera.CFrame = CFrame.new(mouth + Vector3.new(-120 + progress * 360, 0, 0))
		tick(1 / 60)
		if frame > 180 then
			assert(
				math.abs(workspace.Terrain.WaterWaveSize - previousRipple) < 0.01,
				"Lake-to-sea travel must blend smoothly in both directions"
			)
		end
		previousRipple = workspace.Terrain.WaterWaveSize
	end
end
-- Sailing across open water: masks are redone a few ribbons per frame, and recentering
-- only probes the newly uncovered cells, so no single frame fires the whole grid's rays.
camera.CFrame = CFrame.new(1500, 12, 0)
tick(1 / 60)
local busiestFrame, sailingRays = 0, rays
for frame = 1, 600 do
	camera.CFrame = CFrame.new(1500 + frame * 0.5, 12, frame * 0.2)
	local before = rays
	tick(1 / 60)
	busiestFrame = math.max(busiestFrame, rays - before)
end
-- Three ribbons (seven rays each) plus one coastline sample (eight rays) at most.
assert(busiestFrame <= 3 * 7 + 8, "Water masks must not probe in bursts: " .. busiestFrame)
assert(rays - sailingRays > 49 * 7 * 5, "Water masks must keep refreshing while sailing")
assert(enabledCount() > 0, "Open water must keep its crests while sailing")
camera.CFrame = CFrame.new(0, -3, 0)
tick(0.04)
assert(enabledCount() == 0, "Submerged camera must hide surface ribbons")
print(
	"PASS swell clearance, grid recycling, fixed textures, shared boat heights, land/hull masks, camera lifecycle and smooth coasts"
)
print("Recording mocks only; Studio rendering and physical boat behavior remain unverified.")
