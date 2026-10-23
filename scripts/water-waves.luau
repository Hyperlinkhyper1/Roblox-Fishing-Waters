-- MOCKS --
Vector3.one = Vector3.new(1, 1, 1)
local RaycastParams = {
	new = function()
		return {}
	end,
}
local heartbeat = { callbacks = {} }
function heartbeat:Connect(callback)
	table.insert(self.callbacks, callback)
end
function heartbeat:Fire(dt)
	for _, callback in self.callbacks do
		callback(dt)
	end
end
local localPlayer = { Character = Instance.new("Model") }
game.GetService = function(_, name)
	return if name == "Players"
		then { LocalPlayer = localPlayer }
		elseif name == "RunService" then { Heartbeat = heartbeat }
		else {}
end
workspace = Instance.new("Folder")
workspace.Terrain = {
	WaterColor = Color3.fromRGB(30, 80, 96),
	WaterWaveSize = 0.1,
	WaterWaveSpeed = 8,
}
workspace:SetAttribute("WeatherEpoch", 0)
workspace:SetAttribute("WeatherOverride", "Storm")
local now, rays, dry = 1000, 0, false
function workspace:GetServerTimeNow()
	return now
end
function workspace:Raycast(origin, direction, parameters)
	rays += 1
	assert(direction.Y < 0 and not parameters.IgnoreWater, "Water rays must include the surface")
	assert(#parameters.FilterDescendantsInstances == 2, "Local visuals and character must be excluded")
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
	heartbeat:Fire(dt)
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
assert(#pool > 0 and #pool <= 100 and #heartbeat.callbacks == 1, "Startup must keep one bounded render pool")
local motion, previous = false, {}
local maximumSeaHeight = 0
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
		assert(
			math.abs(attachment.CFrame.RightVector:Dot(attachment.CFrame.UpVector)) < 1e-5,
			"Water ribbons must lie in the sampled surface tangent plane"
		)
	end
end
assert(motion and maximumSeaHeight > 0.3, "Storm crests must visibly move and rise above the sea")
assert(enabledCount() > 0, "Open water must show crests")
local seaRipple = workspace.Terrain.WaterWaveSize
dry = true
tick(1)
assert(enabledCount() == 0, "Dry land must mask all swells")
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
camera.CFrame = CFrame.new(0, -3, 0)
tick(0.04)
assert(enabledCount() == 0, "Submerged camera must hide surface ribbons")
print(
	"PASS pooled swell movement, shared boat heights, land masks, camera teleport/absence/recovery and sheltered lake ripples"
)
print("Recording mocks only; Studio rendering and physical boat behavior remain unverified.")
