-- MOCKS --
local Content = { fromObject = function(object) return { object = object } end }
local warnings = {}
local function warn(message)
	table.insert(warnings, message)
end
local pending = {}
task.spawn = function(callback, ...)
	local args = table.pack(...)
	table.insert(pending, coroutine.create(function()
		callback(table.unpack(args, 1, args.n))
	end))
end
task.wait = function()
	coroutine.yield()
end
local function flush()
	for _ = 1, 10000 do
		if #pending == 0 then return end
		local current = table.remove(pending, 1)
		local ok, message = coroutine.resume(current)
		assert(ok, tostring(message))
		if coroutine.status(current) ~= "dead" then table.insert(pending, current) end
	end
	error("Fish builders did not finish")
end
function instanceMethods:GetPropertyChangedSignal(_property)
	return { Connect = function() end }
end
function instanceMethods:Clone()
	local clone = Instance.new(self.ClassName)
	for key, value in self._props do
		if key ~= "Parent" then clone[key] = value end
	end
	return clone
end
local created, templates = {}, {}
local liveDynamic, peakDynamic, allocations, copies = 0, 0, 0, 0
local failure, failAt = nil, 1
local function newMesh(fixed)
	local mesh = { FixedSize = fixed, points = {}, normals = {}, faces = {} }
	if not fixed then
		liveDynamic += 1
		peakDynamic = math.max(peakDynamic, liveDynamic)
	end
	function mesh:AddVertex(point)
		if failure == "geometry" then error("Geometry failed") end
		table.insert(self.points, point)
		return #self.points
	end
	function mesh:AddNormal(normal)
		table.insert(self.normals, normal)
		return #self.normals
	end
	function mesh:AddTriangle(a, b, c)
		table.insert(self.faces, { a, b, c })
		return #self.faces
	end
	function mesh:SetFaceNormals(id, normals)
		assert(self.faces[id] and #normals == 3)
	end
	function mesh:GetFaces()
		local ids = {}
		for id in self.faces do table.insert(ids, id) end
		return ids
	end
	function mesh:RemoveFace(id)
		assert(not self.FixedSize, "Only the scratch mesh is cleared")
		self.faces[id] = nil
	end
	function mesh:RemoveUnused()
		assert(next(self.faces) == nil, "Scratch must be emptied of faces first")
		self.points, self.normals, self.faces = {}, {}, {}
	end
	function mesh:Destroy()
		assert(not self.destroyed, "Mesh must be released exactly once")
		self.destroyed = true
		if not self.FixedSize then liveDynamic -= 1 end
	end
	table.insert(created, mesh)
	return mesh
end
local assetService = {}
function assetService:CreateEditableMesh()
	allocations += 1
	if allocations == failAt then
		if failure == "budget" then return nil end
		if failure == "access" then error("API unavailable") end
	end
	return newMesh(false)
end
function assetService:CreateEditableMeshAsync(content, options)
	copies += 1
	task.wait() -- Deliberately interleave species builds at both yielding APIs.
	assert(options.FixedSize and not content.object.destroyed)
	if copies == failAt then
		if failure == "copy-budget" then return nil end
		if failure == "copy-error" then error("Fixed-size copy failed") end
	end
	local fixed = newMesh(true)
	fixed.points = table.clone(content.object.points)
	fixed.faces = table.clone(content.object.faces)
	return fixed
end
function assetService:CreateMeshPartAsync(content)
	task.wait()
	if failure == "part" then error("Mesh part failed") end
	assert(content.object.FixedSize and not content.object.destroyed)
	local part = Instance.new("Part")
	part.mesh = content.object
	table.insert(templates, part)
	return part
end
local collection = {
	GetInstanceAddedSignal = function() return { Connect = function() end } end,
	GetTagged = function() return {} end,
}
game.GetService = function(_, name)
	return if name == "AssetService" then assetService elseif name == "CollectionService" then collection else {}
end
local rings = {
	{ x = 1, top = 0.2, bottom = -0.2, width = 0.2 },
	{ x = 0, top = 0.5, bottom = -0.5, width = 0.4 },
	{ x = -1, top = 0.1, bottom = -0.1, width = 0.1 },
}
dependencies.FishModels = {
	SCALE = 1,
	loft = function(id)
		return {
			rings = rings, mode = if id == "flat" then "flat" else nil,
			anchorSize = Vector3.one, anchorPosition = Vector3.zero,
		}
	end,
	loftPoint = function(ring, angle)
		return Vector3.new(ring.x, ring.top * math.cos(angle), ring.width * math.sin(angle))
	end,
	loftNormal = function(_rings, _x, angle)
		return Vector3.new(0, math.cos(angle), math.sin(angle))
	end,
}
local function loadBudget()
	-- BUDGET --
end
local function loadClient()
	-- CLIENT --
end
local function reset()
	assert(#pending == 0)
	created, templates, warnings = {}, {}, {}
	liveDynamic, peakDynamic, allocations, copies = 0, 0, 0, 0
	failure, failAt = nil, 1
	dependencies.EditableMeshBudget = loadBudget()
	return loadClient()
end
local world = Instance.new("Folder")
local function fish(id)
	local model = Instance.new("Model")
	model:SetAttribute("LoftFish", id)
	model.Parent = world
	for _, name in { "Back", "Side", "Belly" } do
		local swatch = Instance.new("Part")
		swatch:SetAttribute("LoftSwatch", name)
		swatch:SetAttribute("LoftFallback", true)
		swatch.Color = Color3.fromRGB(50, 100, 150)
		swatch.Material = Enum.Material.SmoothPlastic
		swatch.Reflectance = 0
		swatch.Parent = model
		local mesh = Instance.new("SpecialMesh")
		mesh.Scale = Vector3.one
		mesh.Parent = swatch
	end
	return model
end
local function visibleFallback(model)
	return model:GetChildren()[1]:FindFirstChildOfClass("SpecialMesh").Scale.Magnitude > 0
end
local function assertReleased()
	assert(liveDynamic == 0, "Temporary dynamic meshes must be released")
	for _, mesh in created do
		assert(mesh.destroyed, "An unsuccessful species must release every mesh")
	end
end

local client = reset()
local models = {}
for _, id in { "round", "flat", "other", "round", "flat", "other" } do
	local model = fish(id)
	table.insert(models, model)
	task.spawn(client.hydrate, model)
end
flush()
assert(peakDynamic == 1 and liveDynamic == 0, "Simultaneous species must share one temporary dynamic mesh")
assert(#templates == 16 and copies == 16, "Species templates must be cached, including flatfish")
assert(allocations == 3, "Each species must build every band in one reused scratch mesh")
for _, mesh in created do
	assert(mesh.FixedSize ~= (mesh.destroyed == true), "Only fixed-size skins stay alive")
end
for _, model in models do
	assert(not visibleFallback(model), "Completed skins must replace fallback geometry")
	local count = 0
	for _, part in model:GetChildren() do
		if part.Name == "LoftSkin" then
			count += 1
			assert(part.mesh.FixedSize and not part.mesh.destroyed and #part.mesh.faces > 0)
			assert(not part.CanCollide and part.Transparency == 0 and part.Color.G == 100 / 255)
		end
	end
	assert(count == (if model:GetAttribute("LoftFish") == "flat" then 2 else 7))
end
print("PASS concurrent species use one dynamic mesh, keep fixed skins, reuse templates and hydrate flatfish")

for _, reason in { "budget", "access", "copy-budget", "copy-error" } do
	client = reset()
	failure = reason
	local fallback = fish("round")
	task.spawn(client.hydrate, fallback)
	for index = 1, 12 do task.spawn(client.hydrate, fish("species" .. index)) end
	flush()
	assert(allocations == 1, "A failed allocation must stop all later species: " .. reason)
	assert(dependencies.EditableMeshBudget.create() == nil and allocations == 1, "Water must share the failed budget")
	assert(visibleFallback(fallback), "Allocation failure must preserve fallback geometry")
	assertReleased()
end
print("PASS budget/API failures stop further engine allocations across species and water")

for _, reason in { "geometry", "part", "copy-budget" } do
	client = reset()
	failure, failAt = reason, 3
	local fallback = fish("round")
	task.spawn(client.hydrate, fallback)
	flush()
	assert(visibleFallback(fallback), "Incomplete skins must leave the original body visible")
	assertReleased()
	for _, part in templates do assert(part.Parent == nil, "Discard partial templates") end
	failure = nil
	local nextFish = fish("other")
	task.spawn(client.hydrate, nextFish)
	flush()
	if reason == "geometry" or reason == "part" then
		assert(not visibleFallback(nextFish), "Non-budget failure must release the species build lock")
	else
		assert(visibleFallback(nextFish) and allocations == 1, "Budget failure must stay latched")
	end
end
print("PASS partial-build, geometry and mesh-part failures release resources and keep fallbacks visible")

client = reset()
local completed = fish("round")
task.spawn(client.hydrate, completed)
flush()
local completedMeshes = table.clone(created)
failure, failAt = "copy-budget", copies + 3
task.spawn(client.hydrate, fish("other"))
flush()
local attempts = allocations
local cached = fish("round")
task.spawn(client.hydrate, cached)
flush()
assert(not visibleFallback(completed) and not visibleFallback(cached) and allocations == attempts)
for _, mesh in completedMeshes do
	if mesh.FixedSize then assert(not mesh.destroyed, "Budget exhaustion must preserve completed skins") end
end
for index = #completedMeshes + 1, #created do
	assert(created[index].destroyed, "Only the incomplete species should be discarded")
end
print("PASS exhausted budgets preserve completed skins and allow cached species to hydrate")

client = reset()
client.start()
local report
task.spawn(function() report = client.diagnose() end)
flush()
assert(report:find("Mesh test PASS", 1, true), "Diagnostic must report a successful skin")
client = reset()
failure = "access"
client.start()
task.spawn(function() report = client.diagnose() end)
flush()
assert(report:find("Mesh test FAILED", 1, true) and report:find("API unavailable", 1, true), "Diagnostic must preserve the API failure")
print("PASS mesh diagnostic reports success and the underlying allocation error")
client = reset()
failure, failAt = "budget", 1
local releasedWater = 0
dependencies.EditableMeshBudget.onRelease("SwellSurface", function() releasedWater += 1 end)
local evictedFish = fish("round")
task.spawn(client.hydrate, evictedFish)
flush()
assert(releasedWater == 1, "A starved fish skin must release the cosmetic water mesh")
assert(not visibleFallback(evictedFish) and allocations == 2, "The skin must build after the water mesh is released")
assert(dependencies.EditableMeshBudget.status():find("Released for fish: SwellSurface", 1, true))
print("PASS fish skins evict the swell sheet when the device budget is full")

-- The reported failure: the last band's fixed copy doesn't fit. Skins of
-- species no fish is wearing give their meshes back and the build continues.
client = reset()
local idle = fish("round")
task.spawn(client.hydrate, idle)
flush()
local idleMeshes = {}
for _, mesh in created do
	if mesh.FixedSize then table.insert(idleMeshes, mesh) end
end
assert(#idleMeshes == 7)
local worn = fish("flat")
task.spawn(client.hydrate, worn)
flush()
idle.Parent = nil
failure, failAt = "copy-budget", copies + 7
local starved = fish("other")
task.spawn(client.hydrate, starved)
flush()
assert(not visibleFallback(starved), "A starved species must build after idle skins are reclaimed")
for _, mesh in idleMeshes do assert(mesh.destroyed, "Idle species skins must be reclaimed") end
assert(not visibleFallback(worn), "Skins still worn by a fish must survive")
for _, part in worn:GetChildren() do
	if part.Name == "LoftSkin" then assert(not part.mesh.destroyed, "Worn skins keep their meshes") end
end
assert(liveDynamic == 0)
assert(dependencies.EditableMeshBudget.status():find("IdleFishSkins", 1, true))
idle.Parent = world
local idleSkinned = false
task.spawn(client.hydrate, idle)
flush()
for _, part in idle:GetChildren() do
	if part.Name == "LoftSkin" and not part.mesh.destroyed then idleSkinned = true end
end
assert(idleSkinned, "A returning fish of a reclaimed species must be re-skinned")
print("PASS a full budget reclaims idle species skins and keeps worn ones")

client = reset()
failure = "budget"
client.start()
local latched = fish("round")
task.spawn(client.hydrate, latched)
flush()
assert(visibleFallback(latched) and allocations == 1)
failure = nil
local untagged = collection.GetTagged
collection.GetTagged = function() return { latched } end
task.spawn(function() report = client.diagnose() end)
flush()
collection.GetTagged = untagged
assert(report:find("Rainbow Trout skin available", 1, true), "The mesh test must retry a latched budget")
assert(not visibleFallback(latched), "A successful retry must re-skin fish left as spheres")
print("PASS mesh test retries a latched failure and re-skins fallback fish")
print("Recording mocks only; actual device memory and Studio appearance require play testing.")
