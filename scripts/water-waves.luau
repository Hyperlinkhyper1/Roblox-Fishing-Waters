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
local motion, previous = false, {}
local maximumSeaHeight = 0
local strongestCrestOpacity = 0
for _ = 1, 120 do
	tick(1 / 30)
	for _, beam in pool do
		if not beam.Enabled then
			continue
		end
		local attachment = beam.Attachment0
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
assert(seaRipple > 0.7 and seaRipple <= 1, "Storm surface must visibly roll within the engine wave-height limit")
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
local testAmplitude = 0.05
dependencies.Weather.heightAt = function()
	return testAmplitude * 0.8, testAmplitude
end
tick(1 / 60)
assert(enabledCount() == 0, "Tiny sheltered waves must not draw intersecting ribbons")
testAmplitude = 0.24
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
dependencies.Weather.heightAt = realHeightAt
local FULL_RIBBON_LENGTH = 19 * 2 - 0.5
-- A boat beside the camera: no ribbon may draw inside its hull footprint.
local boats = Instance.new("Folder")
boats.Name = "PlayerBoats"
boats.Parent = workspace
local boat = Instance.new("Model")
boat.Parent = boats
local hullSize = Vector3.new(12, 6, 30)
function boat:GetBoundingBox()
	return CFrame.new(1500, 2, 0), hullSize
end
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
tick(1)
tick(1)
assert(enabledCount() == 0, "Dry land must mask all swells")
assert(
	workspace.Terrain.WaterWaveSize < seaRipple * 0.1,
	"Coastal viewpoints must suppress native oscillations that clip through the shoreline"
)
dry = false
tick(1)
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
assert(enabledCount() > 0 and #beams() == #pool, "Camera recovery must reuse its render pool")
assert(workspace.Terrain.WaterWaveSize < seaRipple * 0.5, "Lake ripples must be smaller than open-sea ripples")
assert(workspace.Terrain.WaterWaveSize < 0.3, "Inner lake must retain sheltered waves")
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
assert(busiestFrame < 49 * 7 / 2, "Water masks must not probe the whole grid in one frame: " .. busiestFrame)
assert(rays - sailingRays > 49 * 7 * 10, "Water masks must keep refreshing while sailing")
assert(enabledCount() > 0, "Open water must keep its crests while sailing")
camera.CFrame = CFrame.new(0, -3, 0)
tick(0.04)
assert(enabledCount() == 0, "Submerged camera must hide surface ribbons")
print(
	"PASS pooled swell movement, shared boat heights, land/hull masks, camera lifecycle, sheltered lake and smooth coast transitions"
)
print("Recording mocks only; Studio rendering and physical boat behavior remain unverified.")
