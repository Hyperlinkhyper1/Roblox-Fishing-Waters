-- Gives loft fish (FishModels.LOFT_TAG) their smooth skin on this client,
-- wherever they are: hands, freezers, customers' arms and menu viewports.
-- Servers build the sphere body and each client swaps it out for baked mesh
-- parts once the entire skin is ready. Skins copy their colour, material and
-- transparency from the body's Chest swatches, so mutation painting and the
-- Rainbow/Glitch animations carry over. If a mesh can't be made, the sphere
-- body simply stays.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishModels = require(ReplicatedStorage.Shared.FishModels)
local MeshFeatures = require(ReplicatedStorage.Shared.MeshFeatures)
local EditableMeshBudget = require(script.Parent.EditableMeshBudget)

local FishMeshes = {}
-- Angle steps from back to belly on one flank.
local ANGLE_STEPS = 28
-- Colour bands from back to belly (fractions of pi). Blend bands mix their two
-- swatches, softening the countershading.
local BANDS = {
	{ name = "Back", from = 0, to = 0.34, a = "Back", b = "Back", mix = 0 },
	{ name = "BackSide", from = 0.34, to = 0.42, a = "Back", b = "Side", mix = 0.35 },
	{ name = "SideBack", from = 0.42, to = 0.48, a = "Back", b = "Side", mix = 0.7 },
	{ name = "Side", from = 0.48, to = 0.62, a = "Side", b = "Side", mix = 0 },
	{ name = "SideBelly", from = 0.62, to = 0.68, a = "Side", b = "Belly", mix = 0.35 },
	{ name = "BellySide", from = 0.68, to = 0.74, a = "Side", b = "Belly", mix = 0.7 },
	{ name = "Belly", from = 0.74, to = 1, a = "Belly", b = "Belly", mix = 0 },
}
-- Flatfish (loft mode "flat") lie on their side: one colour per face.
local FLAT_BANDS = {
	{ name = "Top", from = 0, to = 1, a = "Side", b = "Side", mix = 0, sides = { 1 } },
	{ name = "Under", from = 0, to = 1, a = "Belly", b = "Belly", mix = 0, sides = { -1 } },
}
local function bandsFor(spec)
	return if spec.mode == "flat" then FLAT_BANDS else BANDS
end
local PAINTED = { "Color", "Material", "Reflectance", "Transparency" }
local started = false
type SkinBand = { part: MeshPart, offset: Vector3 }
type Skin = { [string]: SkinBand }
local skins: { [string]: Skin } = {}
local recentSkins: { string } = {}
local MAX_CACHED_SKINS = 48
local skinErrors: { [string]: string } = {}
-- A failed species is retried after this long (the budget may have freed up).
local SKIN_RETRY_AFTER = 30
local skinFailedAt: { [string]: number } = {}
-- Fish skins outrank cosmetic meshes such as the swell water sheet.
local ALLOCATE = { evict = true }
local FORCED = { evict = true, force = true }
-- Baking and part creation yield. Only one species may hold a
-- temporary dynamic mesh at a time, even when many tagged fish arrive together.
local building = false
-- False while loading, true once every band is attached.
local hydrated: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- A cloned fish can already have a skin, with no bindings to its new swatches.
-- Restore its original body while the skin is being attached to the clone.
local function restoreBody(model: Model)
	for _, item in model:GetDescendants() do
		if item.Name == "LoftSkin" then
			item:Destroy()
		elseif item:GetAttribute("LoftFallback") then
			local mesh = item:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				local scale = mesh:GetAttribute("LoftFallbackScale")
				if typeof(scale) == "Vector3" then
					mesh.Scale = scale
				end
			end
		end
	end
end

-- Baked content is held by each MeshPart using it. Trim old templates without
-- affecting fish that are still showing those skins.
local function touchSkin(fishId: string)
	local index = table.find(recentSkins, fishId)
	if index then
		table.remove(recentSkins, index)
	end
	table.insert(recentSkins, fishId)
	if #recentSkins > MAX_CACHED_SKINS then
		local oldest = table.remove(recentSkins, 1) :: string
		for _, band in skins[oldest] do
			band.part:Destroy()
		end
		skins[oldest] = nil
	end
end

-- One line on what this client holds, for the mesh test.
local function cacheStatus(): string
	local species, meshes = 0, 0
	for _, bands in skins do
		if bands then
			species += 1
			for _ in bands do
				meshes += 1
			end
		end
	end
	return string.format("Cached fish skins: %d species, %d meshes.", species, meshes)
end

-- One band of the skin as a mesh part, its vertices centred on its bounds.
-- Bake it to static mesh content before reusing the scratch mesh for the next band.
local function buildBand(scratch: EditableMesh, rings, band): (MeshPart, Vector3)
	local scale = FishModels.SCALE
	local steps = math.max(2, math.ceil((band.to - band.from) * ANGLE_STEPS))
	local points, normals = {}, {}
	local grids = {}
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local function add(point: Vector3, normal: Vector3): number
		table.insert(points, point)
		table.insert(normals, normal)
		low, high = low:Min(point), high:Max(point)
		return #points
	end
	local first, last = rings[1], rings[#rings]
	local snout = add(
		Vector3.new(first.x + 0.006, (first.top + first.bottom) / 2, 0) * scale,
		Vector3.new(1, 0, 0)
	)
	local tail = add(Vector3.new(last.x - 0.004, (last.top + last.bottom) / 2, 0) * scale, Vector3.new(-1, 0, 0))
	local sides = band.sides or { 1, -1 }
	for _, side in sides do
		local grid = {}
		for ringIndex, ring in rings do
			local row = {}
			for step = 0, steps do
				local angle = side * math.pi * (band.from + (band.to - band.from) * step / steps)
				row[step] = add(FishModels.loftPoint(ring, angle) * scale, FishModels.loftNormal(rings, ring.x, angle))
			end
			grid[ringIndex] = row
		end
		grids[side] = grid
	end
	local center = (low + high) / 2

	EditableMeshBudget.clear(scratch)
	local vertexIds, normalIds = {}, {}
	for index, point in points do
		vertexIds[index] = scratch:AddVertex(point - center)
		normalIds[index] = scratch:AddNormal(normals[index])
	end
	-- Wound so (b - a) x (c - a) faces outward, the side Roblox draws.
	local function face(a: number, b: number, c: number)
		local pa = points[a]
		local cross = (points[b] - pa):Cross(points[c] - pa)
		if cross.Magnitude < 1e-10 then
			return
		end
		if cross:Dot(normals[a] + normals[b] + normals[c]) < 0 then
			b, c = c, b
		end
		local id = scratch:AddTriangle(vertexIds[a], vertexIds[b], vertexIds[c])
		scratch:SetFaceNormals(id, { normalIds[a], normalIds[b], normalIds[c] })
	end
	for _, side in sides do
		local grid = grids[side]
		for ringIndex = 1, #rings - 1 do
			local row, nextRow = grid[ringIndex], grid[ringIndex + 1]
			for step = 0, steps - 1 do
				face(row[step], nextRow[step], nextRow[step + 1])
				face(row[step], nextRow[step + 1], row[step + 1])
			end
		end
		for step = 0, steps - 1 do
			face(snout, grid[1][step], grid[1][step + 1])
			face(tail, grid[#rings][step], grid[#rings][step + 1])
		end
	end

	local result, content = AssetService:CreateDataModelContentAsync(Content.fromObject(scratch))
	if result ~= Enum.CreateContentResult.Success or not content then
		error("CreateDataModelContentAsync: " .. tostring(result), 0)
	end
	local part = AssetService:CreateMeshPartAsync(content, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
	part.Size = high - low
	return part, center
end

-- Band templates for a species, built once and shared by every fish of it.
-- `force` (the mesh test) retries a failed species and the budget right away.
local function skin(fishId: string, force: boolean?, model: Model?): Skin?
	while building do
		task.wait()
	end
	if model and not model.Parent then
		return nil
	end
	local cached = skins[fishId]
	if cached then
		touchSkin(fishId)
		return cached
	end
	local failedAt = skinFailedAt[fishId]
	if failedAt and not force and os.clock() - failedAt < SKIN_RETRY_AFTER then
		return nil
	end
	local spec = FishModels.loft(fishId)
	if not spec then
		skinFailedAt[fishId] = os.clock()
		skinErrors[fishId] = "No smooth-body geometry exists for " .. fishId
		return nil
	end
	building = true
	local options = if force then FORCED else ALLOCATE
	local bands: Skin = {}
	local bandName = "Scratch mesh"
	-- Fish and sharks share the scratch lock; neither can consume a second
	-- maximum-sized dynamic allocation while the other is making skins.
	local ok, complete = pcall(EditableMeshBudget.withScratch, options, function(scratch)
		for _, band in bandsFor(spec) do
			bandName = band.name .. " band"
			local part, center = buildBand(scratch, spec.rings, band)
			bands[band.name] = { part = part, offset = center - spec.anchorPosition }
		end
		return true
	end)
	building = false
	if not ok or not complete then
		for _, built in bands do
			built.part:Destroy()
		end
		skinFailedAt[fishId] = os.clock()
		local reason = if ok then EditableMeshBudget.failureReason() or "EditableMesh allocation failed" else tostring(complete)
		skinErrors[fishId] = bandName .. ": " .. reason
		return nil
	end
	skins[fishId] = bands
	touchSkin(fishId)
	skinErrors[fishId] = nil
	skinFailedAt[fishId] = nil
	return bands
end

-- Retry tagged fish still wearing their fallback bodies.
local function retryUnskinned()
	for _, model in CollectionService:GetTagged(FishModels.LOFT_TAG) do
		if model:IsA("Model") and model.Parent and hydrated[model] == nil then
			task.spawn(FishMeshes.hydrate, model)
		end
	end
end

-- Exercise the Rainbow Trout geometry, then check the fish already on this client.
function FishMeshes.diagnose(): string
	if not MeshFeatures.EditableMeshesEnabled then
		return "Mesh test FAILED: EditableMeshesEnabled is off."
	end
	if not started then
		return "Mesh test FAILED: FishMeshes client has not started."
	end
	local ok, result = pcall(skin, "RainbowTrout", true)
	if not ok then
		return "Mesh test FAILED: " .. tostring(result) .. " " .. EditableMeshBudget.status() .. " " .. cacheStatus()
	end
	if not result then
		return "Mesh test FAILED: " .. (skinErrors.RainbowTrout or "unknown failure") .. " " .. EditableMeshBudget.status() .. " " .. cacheStatus()
	end
	local models = CollectionService:GetTagged(FishModels.LOFT_TAG)
	local retried: { [string]: boolean } = {}
	for _, model in models do
		if model:IsA("Model") and model.Parent then
			while hydrated[model] == false and model.Parent do
				task.wait()
			end
			local fishId = model:GetAttribute("LoftFish")
			if hydrated[model] == nil and model.Parent and type(fishId) == "string" then
				FishMeshes.hydrate(model, not retried[fishId])
				retried[fishId] = true
			end
		end
	end
	local total, skinned, pending = 0, 0, 0
	local firstFailure: string? = nil
	for _, model in models do
		if model:IsA("Model") and model.Parent then
			total += 1
			if hydrated[model] then
				skinned += 1
			else
				pending += 1
				local fishId = model:GetAttribute("LoftFish")
				if type(fishId) == "string" then
					firstFailure = firstFailure or (fishId .. ": " .. (skinErrors[fishId] or "Body swatches unavailable"))
				end
			end
		end
	end
	local summary = string.format("Rainbow Trout skin available. Client fish: %d; with skins: %d; without skins: %d.", total, skinned, pending)
	if firstFailure then
		return "Mesh test PARTIAL: " .. summary .. " Failure: " .. firstFailure .. " " .. EditableMeshBudget.status() .. " " .. cacheStatus()
	end
	if pending > 0 then
		return "Mesh test PARTIAL: " .. summary .. " A tagged fish is missing its species ID."
	end
	return "Mesh test PASS: " .. summary .. " Spots and fins remain separate parts."
end

function FishMeshes.hydrate(model: Instance, force: boolean?)
	if not model:IsA("Model") or not model.Parent or hydrated[model] ~= nil then
		return
	end
	local fishId = model:GetAttribute("LoftFish")
	if type(fishId) ~= "string" then
		return
	end
	restoreBody(model)
	hydrated[model] = false
	local bands = skin(fishId, force, model)
	if not bands or not model.Parent then
		-- Left as a sphere; retryUnskinned() may try again once the budget frees.
		hydrated[model] = nil
		return
	end
	local spec = FishModels.loft(fishId)
	local swatches: { [string]: BasePart } = {}
	for _, item in model:GetDescendants() do
		local swatch = item:GetAttribute("LoftSwatch")
		if type(swatch) == "string" and item:IsA("BasePart") and not swatches[swatch] then
			swatches[swatch] = item
		end
	end
	local anchor = swatches.Side
	swatches.Back = swatches.Back or anchor
	swatches.Belly = swatches.Belly or anchor
	if not anchor then
		hydrated[model] = nil
		return
	end
	local parts = {}
	for _, band in bandsFor(spec) do
		local template = bands[band.name]
		local part = template.part:Clone()
		part.Name = "LoftSkin"
		part.Anchored = false
		part.Massless = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.CastShadow = anchor.CastShadow
		parts[band] = { part = part, size = template.part.Size, offset = template.offset }
	end
	local function paint()
		for band, skinPart in parts do
			local part = skinPart.part
			local a, b = swatches[band.a], swatches[band.b]
			part.Color = a.Color:Lerp(b.Color, band.mix)
			part.Material = a.Material
			part.Reflectance = a.Reflectance
			part.Transparency = a.Transparency
		end
	end
	local welds = {}
	-- Scaled with the Chest swatch, so ScaleTo on either machine keeps it fitted.
	local function place()
		local ratio = anchor.Size.X / spec.anchorSize.X
		for _, weld in welds do
			weld.Enabled = false
		end
		for _, skinPart in parts do
			local part = skinPart.part
			part.Size = skinPart.size * ratio
			part.CFrame = anchor.CFrame * CFrame.new(skinPart.offset * ratio)
		end
		for _, weld in welds do
			weld.Enabled = true
		end
	end
	paint()
	place()
	for _, skinPart in parts do
		local part = skinPart.part
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = anchor, part
		weld.Parent = part
		table.insert(welds, weld)
		part.Parent = anchor.Parent
	end
	for _, swatch in swatches do
		for _, property in PAINTED do
			swatch:GetPropertyChangedSignal(property):Connect(paint)
		end
	end
	anchor:GetPropertyChangedSignal("Size"):Connect(place)
	-- Hide the sphere body visually only; its parts keep carrying particles,
	-- lights and the colours the skin copies.
	for _, item in model:GetDescendants() do
		if item:GetAttribute("LoftFallback") then
			local mesh = item:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				mesh:SetAttribute("LoftFallbackScale", mesh.Scale)
				mesh.Scale = Vector3.zero
			end
		end
	end
	hydrated[model] = true
end

function FishMeshes.start()
	if started then
		return
	end
	started = true
	if not MeshFeatures.EditableMeshesEnabled then
		return
	end
	local retriedAt = os.clock()
	CollectionService:GetInstanceAddedSignal(FishModels.LOFT_TAG):Connect(function(model)
		task.spawn(FishMeshes.hydrate, model)
		-- New fish arrive often (catches, menus); use them to revisit earlier failures.
		if os.clock() - retriedAt >= SKIN_RETRY_AFTER then
			retriedAt = os.clock()
			retryUnskinned()
		end
	end)
	for _, model in CollectionService:GetTagged(FishModels.LOFT_TAG) do
		task.spawn(FishMeshes.hydrate, model)
	end
end

return FishMeshes
