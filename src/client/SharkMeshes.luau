-- Gives sharks their smooth skin on this client. EditableMesh never replicates,
-- so the server builds a stand-in body of ellipsoids and wedge fins (tagged
-- SharkFallback) and each client swaps it for real triangle meshes built from
-- Shared.SharkShape: eighteen skins (five swim segments x three colour bands
-- with the fins, the mouth's roof and a two-part hinged lower jaw), built once
-- and cloned onto every shark. Each skin stores its SwimOffset, SwimSegment and
-- (for the jaw) SwimJaw, so SharkSwim bends and opens it. If meshes
-- can't be made on this device, the stand-in simply stays.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharkShape = require(ReplicatedStorage.Shared.SharkShape)
local MeshFeatures = require(ReplicatedStorage.Shared.MeshFeatures)
local EditableMeshBudget = require(script.Parent.EditableMeshBudget)

local SharkMeshes = {}
local RETRY_AFTER = 30
-- Sharks are rare and few; their skin may claim cosmetic budget like fish do.
local ALLOCATE = { evict = true }
local started = false
local templates: { any }? = nil
local failedAt = -math.huge
local building = false
local hydrated: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function color(band: string): Color3
	local c = SharkShape.COLORS[band]
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- One skin as a mesh part, its vertices centred on its bounds.
local function buildSkin(spec): (MeshPart?, Vector3?, EditableMesh?)
	local points, normals = {}, {}
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for index, p in spec.positions do
		local point = Vector3.new(p[1], p[2], p[3])
		local n = spec.normals[index]
		points[index], normals[index] = point, Vector3.new(n[1], n[2], n[3])
		low, high = low:Min(point), high:Max(point)
	end
	local center = (low + high) / 2
	local mesh = EditableMeshBudget.create(ALLOCATE)
	if not mesh then
		return nil, nil, nil
	end
	local ok, part = pcall(function()
		local vertexIds, normalIds = {}, {}
		for index, point in points do
			vertexIds[index] = mesh:AddVertex(point - center)
			normalIds[index] = mesh:AddNormal(normals[index])
		end
		-- SharkShape already winds every triangle outward, the side Roblox draws.
		for _, tri in spec.triangles do
			local id = mesh:AddTriangle(vertexIds[tri[1]], vertexIds[tri[2]], vertexIds[tri[3]])
			mesh:SetFaceNormals(id, { normalIds[tri[1]], normalIds[tri[2]], normalIds[tri[3]] })
		end
		mesh = EditableMeshBudget.fixed(mesh, ALLOCATE)
		if not mesh then
			return nil
		end
		return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not ok or not part then
		if mesh then
			mesh:Destroy()
		end
		if not ok then
			warn("[SharkMeshes] Could not create a shark skin: " .. tostring(part))
		end
		return nil, nil, nil
	end
	part.Size = high - low
	return part, center, mesh
end

-- The skins, built once per client; nil while unavailable.
local function skins()
	while building do
		task.wait()
	end
	if templates or os.clock() - failedAt < RETRY_AFTER then
		return templates
	end
	building = true
	local built = {}
	for _, spec in SharkShape.build() do
		local part, center, mesh = buildSkin(spec)
		if not part or not center or not mesh then
			for _, skin in built do
				skin.part:Destroy()
				skin.mesh:Destroy()
			end
			failedAt = os.clock()
			building = false
			return nil
		end
		table.insert(built, { part = part, mesh = mesh, offset = CFrame.new(center), segment = spec.segment, band = spec.band, jaw = spec.jaw == true })
		task.wait()
	end
	templates = built
	building = false
	return templates
end

function SharkMeshes.hydrate(model: Instance)
	if not model:IsA("Model") or hydrated[model] then
		return
	end
	hydrated[model] = true
	local list = skins()
	local root = model.PrimaryPart
	if not list or not root or not model.Parent then
		hydrated[model] = nil
		return
	end
	for _, skin in list do
		local part = skin.part:Clone()
		part.Name = "SharkSkin"
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Massless = true
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0.04
		part.Color = color(skin.band)
		part:SetAttribute("SwimOffset", skin.offset)
		part:SetAttribute("SwimSegment", skin.segment)
		if skin.jaw then
			part:SetAttribute("SwimJaw", true)
		end
		part.CFrame = root.CFrame * skin.offset
		part.Parent = model
	end
	-- The stand-in body is only removed here; the server copy is untouched.
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("SharkFallback") == true then
			item:Destroy()
		end
	end
end

function SharkMeshes.start()
	if started then
		return
	end
	started = true
	if not MeshFeatures.EditableMeshesEnabled then
		return
	end
	local folder = workspace:WaitForChild("Sharks")
	local function add(model: Instance)
		-- Streaming hands over the whole model at once (Atomic), root included.
		task.spawn(SharkMeshes.hydrate, model)
	end
	folder.ChildAdded:Connect(add)
	for _, model in folder:GetChildren() do
		add(model)
	end
	-- Sharks left on the stand-in because meshes failed get another chance.
	task.spawn(function()
		while true do
			task.wait(RETRY_AFTER)
			for _, model in folder:GetChildren() do
				-- A failed hydrate clears its mark; one still in progress keeps it.
				if model:IsA("Model") and not hydrated[model] and not model:FindFirstChild("SharkSkin") then
					add(model)
				end
			end
		end
	end)
end

return SharkMeshes
