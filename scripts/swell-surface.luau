-- MOCKS --
task.spawn = function(callback, ...)
	return callback(...)
end
local RaycastParams = {
	new = function()
		return {}
	end,
}
local Content = {
	fromObject = function(object)
		return { object = object }
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
-- Recording EditableMesh: ids index plain arrays.
local meshes = {}
local function newMesh()
	local mesh =
		{ positions = {}, normals = {}, colors = {}, alphas = {}, faces = {}, faceNormals = {}, faceColors = {} }
	function mesh:AddVertex(position)
		table.insert(self.positions, position)
		return #self.positions
	end
	function mesh:AddNormal(normal)
		table.insert(self.normals, normal)
		return #self.normals
	end
	function mesh:AddColor(color, alpha)
		table.insert(self.colors, color)
		table.insert(self.alphas, alpha)
		return #self.colors
	end
	function mesh:AddTriangle(a, b, c)
		table.insert(self.faces, { a, b, c })
		return #self.faces
	end
	function mesh:SetFaceNormals(face, ids)
		self.faceNormals[face] = ids
	end
	function mesh:SetFaceColors(face, ids)
		self.faceColors[face] = ids
	end
	function mesh:SetPosition(id, position)
		assert(self.positions[id], "Unknown vertex")
		self.positions[id] = position
	end
	function mesh:SetNormal(id, normal)
		assert(self.normals[id], "Unknown normal")
		self.normals[id] = normal
	end
	function mesh:SetColor(id, color)
		self.colors[id] = color
	end
	function mesh:SetColorAlpha(id, alpha)
		assert(alpha >= 0 and alpha <= 1, "Alpha must be a fraction")
		self.alphas[id] = alpha
	end
	table.insert(meshes, mesh)
	return mesh
end
local meshParts = {}
local localPlayer = { Character = Instance.new("Model") }
game.GetService = function(_, name)
	return if name == "Players"
		then {
			GetPlayers = function()
				return { localPlayer }
			end,
		}
		elseif name == "RunService" then { RenderStepped = renderStep }
		elseif name == "AssetService" then {
			CreateEditableMesh = function()
				return newMesh()
			end,
			CreateMeshPartAsync = function(_, content)
				local part = Instance.new("Part")
				part.mesh = content.object
				part.LocalTransparencyModifier = 0
				table.insert(meshParts, part)
				return part
			end,
		}
		else {}
end
workspace = Instance.new("Folder")
workspace.Terrain = { WaterColor = Color3.fromRGB(30, 80, 96) }
workspace:SetAttribute("WeatherEpoch", 0)
workspace:SetAttribute("WeatherSeed", 888)
workspace:SetAttribute("WeatherOverride", "Storm")
local now, rays, dry = 1000, 0, false
function workspace:GetServerTimeNow()
	return now
end
function workspace:Raycast(origin, direction, parameters)
	rays += 1
	assert(direction.Y < 0 and not parameters.IgnoreWater, "Water rays must include the surface")
	assert(table.find(parameters.FilterDescendantsInstances, localPlayer.Character), "Characters must be excluded")
	return { Material = if dry or origin.X < 1560 then Enum.Material.Sand else Enum.Material.Water }
end
local camera = { CFrame = CFrame.new(1700, 12, 0) }
workspace.CurrentCamera = camera
local function loadBiomes()
	-- BIOMES --
end
dependencies.Biomes = loadBiomes()
local function loadWeather()
	-- WEATHER --
end
dependencies.Weather = loadWeather()
local Weather, Biomes = dependencies.Weather, dependencies.Biomes
local function loadClient()
	-- CLIENT --
end
local Client = loadClient()
local function tick(dt)
	now += dt
	renderStep:Fire(dt)
end

Client.start()
Client.start()
assert(#meshes == 1 and #meshParts == 1 and #renderStep.callbacks == 1, "Startup must build one sheet")
local mesh, part = meshes[1], meshParts[1]
assert(#mesh.positions <= 2500 and #mesh.faces == 2 * (math.sqrt(#mesh.positions) - 1) ^ 2, "Bounded, fully tiled grid")
assert(not part.CanCollide and not part.CanQuery and not part.CanTouch, "The sheet must never collide or block rays")
for face, ids in mesh.faces do
	local a, b, c = mesh.positions[ids[1]], mesh.positions[ids[2]], mesh.positions[ids[3]]
	assert((b - a):Cross(c - a).Y > 0, "Triangles must face up")
	assert(mesh.faceNormals[face] and mesh.faceColors[face], "Every face shares its vertices' normals and colors")
end

-- First probes are spread over frames (40 cells each), so the sheet fills in over ~2 s.
for _ = 1, 120 do
	tick(1 / 30)
end
local state = Weather.getState(now)
local matched, crests, troughs, sunk = 0, 0, 0, 0
for id, local_ in mesh.positions do
	local world = part.CFrame:PointToWorldSpace(local_)
	local alpha = mesh.alphas[id]
	if world.X < 1560 + 40 then
		-- Over land, or tapering into it.
		if world.X < 1560 then
			assert(local_.Y < 0 and alpha == 0, "Land must hide the sheet")
			sunk += 1
		end
		continue
	end
	local offset = world - part.CFrame.Position
	local inner = math.max(math.abs(offset.X), math.abs(offset.Z)) < 264 - 72
	if inner then
		local expected = Weather.heightAt(world, now, state)
		assert(
			math.abs(local_.Y - expected) < 0.05 + math.abs(expected) * 0.03,
			"Open-water sheet must show the boats' exact swell height"
		)
		matched += 1
	end
	if local_.Y > 1 then
		assert(alpha > 0.9, "Raised crests must be opaque")
		crests += 1
	elseif local_.Y <= 0 then
		assert(alpha == 0, "Troughs beneath Terrain water must not show")
		troughs += 1
	end
end
assert(
	matched > 500 and crests > 50 and troughs > 50 and sunk > 50,
	"Check must see crests, troughs, open water and land"
)
assert(part.LocalTransparencyModifier == 0, "Above water the sheet is shown")

-- Boats ride the visible surface: never below Terrain water.
for step = 0, 40 do
	local position = Vector3.new(1700 + step * 7, 0, step * 3)
	local hull = Weather.hullSample(position, Vector3.new(0, 0, -1), 12, 4, now + step * 0.37, nil, 0)
	assert(hull.height >= 0 and hull.normal.Y > 0.9, "Hull sample must sit on the visible surface")
	local free = Weather.hullSample(position, Vector3.new(0, 0, -1), 12, 4, now + step * 0.37)
	assert(hull.height >= free.height - 1e-9, "The floor only raises troughs")
end

-- A hull beside the camera caps the water inside its footprint.
local boats = Instance.new("Folder")
boats.Name = "PlayerBoats"
boats.Parent = workspace
local boat = Instance.new("Model")
boat.Parent = boats
local hullSize = Vector3.new(10, 5, 26)
-- A real hull part, so the boat's bounding box comes from its geometry.
local hull = Instance.new("Part")
hull.Size = hullSize
hull.CFrame = CFrame.new(1700, 1, 0)
hull.Parent = boat
local sole = 1 - hullSize.Y / 2 + 0.5
for _ = 1, 30 do
	tick(1 / 30)
	for _, local_ in mesh.positions do
		local world = part.CFrame:PointToWorldSpace(local_)
		if math.abs(world.X - 1700) < hullSize.X / 2 and math.abs(world.Z) < hullSize.Z / 2 then
			assert(world.Y <= sole - 0.3 + 1e-6, "Water must stay below a boat's sole")
		end
	end
end
boats.Parent = nil

-- Steady sailing probes a bounded number of rays per frame.
local busiest = 0
for frame = 1, 300 do
	camera.CFrame = CFrame.new(1700 + frame * 0.8, 12, frame * 0.3)
	local before = rays
	tick(1 / 60)
	busiest = math.max(busiest, rays - before)
end
assert(busiest <= 260, "Sailing must not probe the whole sheet in one frame: " .. busiest)

camera.CFrame = CFrame.new(1700, -3, 0)
tick(1 / 60)
assert(part.LocalTransparencyModifier == 1, "Underwater cameras must not see a surface ceiling")
camera.CFrame = CFrame.new(1700, 12, 0)
dry = true
-- The sweep rechecks a dozen cells a frame, so a full pass takes several seconds.
for _ = 1, 450 do
	tick(1 / 30)
end
for id, local_ in mesh.positions do
	assert(mesh.alphas[id] == 0, "Streamed land must hide the sheet after its rechecks")
end
print("PASS swell sheet matches boat heights, hides troughs and land, caps under hulls, bounded probes")
print("Recording mocks only; Studio rendering and EditableMesh limits remain unverified.")
