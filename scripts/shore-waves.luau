-- MOCKS --
local originalTypeof = typeof
typeof = function(value)
	return if type(value) == "table" and value.X ~= nil then "Vector3" else originalTypeof(value)
end
function instanceMethods:IsDescendantOf(parent)
	local current = self.Parent
	while current do
		if current == parent then return true end
		current = current.Parent
	end
	return false
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback) end,
		Fire = function(_, ...)
			for _, callback in callbacks do callback(...) end
		end,
	}
end
local added, removed, heartbeat = signal(), signal(), signal()
function CollectionService:GetInstanceAddedSignal() return added end
function CollectionService:GetInstanceRemovedSignal() return removed end
function CollectionService:GetTagged(tag)
	local result = {}
	for _, item in workspace:GetDescendants() do
		if item._tags[tag] then table.insert(result, item) end
	end
	return result
end
game.GetService = function(_, name)
	return if name == "CollectionService" then CollectionService else { Heartbeat = heartbeat, RenderStepped = heartbeat }
end
dependencies.Props = { pick = function() end }
dependencies.Islands.surface = function(_, x, z) return Vector3.new(x, 0.22, z) end
local function loadHarbour()
	-- HARBOUR --
end
local Harbour = loadHarbour()
local function loadClient()
	-- CLIENT --
end
local Client = loadClient()

workspace = Instance.new("Folder")
workspace.Name = "Workspace"
local now = 0
function workspace:GetServerTimeNow() return now end
local camera = { CFrame = CFrame.new() }
workspace.CurrentCamera = camera
local island = Instance.new("Model")
island.Name, island.Parent = "Harbour Isle", workspace
local village = Instance.new("Model")
village.Name, village.Parent = "Village", island
local beach = Instance.new("Model")
beach.Name, beach.Parent = "Beach", village
local umbrella = Instance.new("Model")
umbrella.Name, umbrella.Parent = "Umbrella", beach
local legacy = Instance.new("Model")
legacy.Name, legacy.Parent = "Surf", beach
local ribbon = Instance.new("Model")
ribbon.Name, ribbon.Parent = "FoamRibbon", legacy

Harbour.ensureSurf(workspace, Vector2.zero)
local surf = beach:FindFirstChild("Surf")
assert(surf and surf ~= legacy and legacy.Parent == nil, "Saved ribbons must be replaced")
assert(umbrella.Parent == beach, "Saved beach decorations must survive")
Harbour.ensureSurf(workspace, Vector2.zero)
assert(beach:FindFirstChild("Surf") == surf, "Saved upgrade must be idempotent")
local sources = CollectionService:GetTagged("ShoreWaveSource")
assert(#sources > 8, "Surf must cover the beach")
local shape = Harbour.makeShape(Vector2.zero)
for _, source in sources do
	assert(source:IsA("BasePart") and source.Transparency == 1, "No static white geometry may remain")
	assert(not source.CanCollide and not source.CanTouch and not source.CanQuery, "Surf must not block gameplay")
	for i = 1, 2 do
		local shore = source.Position + source:GetAttribute("Shore" .. i)
		local inland = source:GetAttribute("Inland" .. i)
		assert(math.abs(inland.Magnitude - 1) < 1e-5, "Surf direction must be normalized")
		local wet, dry = shore - inland * 8, shore + inland * 2
		assert(Harbour.coastDistance(shape, Vector2.new(wet.X, wet.Z)) < -4, "Crest must begin offshore")
		assert(Harbour.coastDistance(shape, Vector2.new(dry.X, dry.Z)) > 0, "Crest must travel toward sand")
	end
end
print(`PASS saved surf upgrade, beach preservation and {#sources} shoreline sources`)

local last = -math.huge
for step = 0, 100 do
	local offset, opacity, width = Client.sample(Client.period * step / 101, 0, 0)
	assert(offset > last, "Wave must advance toward the beach")
	assert(opacity >= 0 and opacity <= 0.46 and width > 0, "Wave output must remain bounded")
	last = offset
end
local offshore, invisible = Client.sample(0, 0, 0)
local onshore, dissolved = Client.sample(Client.period * 0.999, 0, 0)
assert(offshore == -10 and onshore > 2.7, "Wave must wash from shallows onto beach")
assert(invisible == 0 and dissolved == 0, "Loop reset must happen while invisible")
print("PASS shoreward motion, runup, fade and invisible loop reset")

Client.start()
Client.start()
local source = sources[math.ceil(#sources / 2)]
local function beams()
	local result = {}
	for _, child in source:GetChildren() do
		if child:IsA("Beam") then table.insert(result, child) end
	end
	return result
end
assert(#beams() == 2, "Repeated startup must not duplicate waves")
camera.CFrame = source.CFrame
local wave = beams()[1]
local along = source:GetAttribute("Along")
local delay = along / 350 + math.sin(along / 55) * 0.08
now = (delay + 0.2) * Client.period
heartbeat:Fire(1 / 30)
local before = wave.Attachment0.CFrame.Position
now += 1
heartbeat:Fire(1 / 30)
local after = wave.Attachment0.CFrame.Position
assert(wave.Enabled and (after - before):Dot(source:GetAttribute("Inland1")) > 1, "Rendered crest must move shoreward")
assert(math.abs(wave.Attachment0.CFrame.UpVector.Y) < 1e-5, "Crest must lie flat on the water")
assert(wave.LocalTransparencyModifier < 1, "Crest must become visible")
assert(wave.Attachment0.CFrame.Position.Y >= 0.16, "Foam must stay above water")
local highRefreshBefore = wave.Attachment0.CFrame.Position
now += 1 / 144
heartbeat:Fire(1 / 144)
assert((wave.Attachment0.CFrame.Position - highRefreshBefore).Magnitude > 0.001,
	"Shore foam must advance on every rendered frame, including 144 Hz displays")
assert(wave.ZOffset > 0, "Foam must be separated from coplanar shoreline surfaces")
camera.CFrame = source.CFrame + Vector3.new(1000, 0, 0)
heartbeat:Fire(1 / 30)
assert(not wave.Enabled, "Distant surf must be culled")
workspace.CurrentCamera = nil
heartbeat:Fire(1 / 30)
assert(not wave.Enabled, "Missing camera must hide waves safely")
workspace.CurrentCamera, camera.CFrame = camera, source.CFrame
added:Fire(source)
assert(#beams() == 2, "Duplicate streaming notification must not duplicate waves")
removed:Fire(source)
assert(#source:GetChildren() == 0, "Streaming removal must clean up beams and attachments")
added:Fire(source)
heartbeat:Fire(1 / 30)
assert(#beams() == 2 and beams()[1].Enabled, "Surf must recover after streaming back in")
print("PASS actual client movement, flat crests, distance culling and streaming cleanup/reload")
