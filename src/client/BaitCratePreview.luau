local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EditableMeshBudget = require(script.Parent.EditableMeshBudget)
local MeshFeatures = require(ReplicatedStorage.Shared.MeshFeatures)

local BaitCratePreview = {}
local rgb = Color3.fromRGB
local wood = { rgb(169, 99, 49), rgb(194, 121, 62), rgb(180, 107, 54) }
local lid = { rgb(203, 135, 72), rgb(216, 151, 83), rgb(195, 124, 63) }
local darkWood, steel, brass = rgb(111, 62, 36), rgb(50, 88, 87), rgb(242, 181, 91)

local template: MeshPart? = nil
local waiting: { [Model]: boolean } = {}
local loading = false
local retryAt = 0

-- Share the crate's dimensions and colors between the mesh and its low-memory preview.
local function buildCrate(piece: (Vector3, Vector3, Color3, number?) -> ())
	local function box(x, y, z, width, height, depth, color, chamfer)
		piece(Vector3.new(x, y, z), Vector3.new(width, height, depth), color, chamfer)
	end
	box(0, -0.12, 0, 3, 1.46, 1.94, darkWood, 0.12)
	box(0, 0.755, 0, 3.22, 0.31, 2.18, darkWood, 0.13)
	for i = 1, 3 do
		local y = -0.57 + (i - 1) * 0.45
		for _, side in { -1, 1 } do
			box(0, y, side * 0.963, 2.8, 0.397, 0.105, wood[i])
			box(side * 1.494, y, 0, 0.105, 0.397, 1.72, wood[i])
		end
		box(0, 0.904, (i - 2) * 0.7, 3.06, 0.08, 0.67, lid[i], 0.055)
	end
	for _, x in { -1.13, 1.13 } do
		box(x, -0.93, 0, 0.40, 0.22, 2.08, darkWood, 0.05)
		box(x, 0.972, 0, 0.25, 0.136, 2.20, steel, 0.022)
		for _, side in { -1, 1 } do
			box(x, -0.11, side * 1.023, 0.25, 1.47, 0.13, steel)
			box(x, 0.757, side * 1.113, 0.25, 0.314, 0.114, steel)
			box(x, -0.63, side * 1.091, 0.084, 0.084, 0.026, brass, 0.01)
		end
	end
	box(0, 0.536, 1.055, 0.37, 0.48, 0.17, steel, 0.025)
	box(0, 0.60, 1.146, 0.24, 0.31, 0.048, brass, 0.022)
	box(0, 0.55, 1.175, 0.088, 0.075, 0.022, darkWood)
end

local function writeMesh(mesh: EditableMesh)
	local colors = {}
	buildCrate(function(center, size, color, chamfer)
		local colorId = colors[color]
		if not colorId then
			colorId = mesh:AddColor(color, 1)
			colors[color] = colorId
		end
		local x, y, z = size.X / 2, size.Y / 2, size.Z / 2
		local c = chamfer or 0
		local outline = if c > 0 then {
			{ -x, -z + c }, { -x + c, -z }, { x - c, -z }, { x, -z + c },
			{ x, z - c }, { x - c, z }, { -x + c, z }, { -x, z - c },
		} else { { -x, -z }, { x, -z }, { x, z }, { -x, z } }
		local bottom, top = {}, {}
		for i, point in outline do
			bottom[i] = mesh:AddVertex(center + Vector3.new(point[1], -y, point[2]))
			top[i] = mesh:AddVertex(center + Vector3.new(point[1], y, point[2]))
		end
		local function triangle(a, b, c, normalId)
			local face = mesh:AddTriangle(a, b, c)
			mesh:SetFaceColors(face, { colorId, colorId, colorId })
			mesh:SetFaceNormals(face, { normalId, normalId, normalId })
		end
		local down, up = mesh:AddNormal(-Vector3.yAxis), mesh:AddNormal(Vector3.yAxis)
		for i = 2, #outline - 1 do
			triangle(bottom[1], bottom[i], bottom[i + 1], down)
			triangle(top[1], top[i + 1], top[i], up)
		end
		for i, point in outline do
			local nextIndex = i % #outline + 1
			local nextPoint = outline[nextIndex]
			local normal = Vector3.new(nextPoint[2] - point[2], 0, point[1] - nextPoint[1]).Unit
			local normalId = mesh:AddNormal(normal)
			triangle(bottom[i], top[i], top[nextIndex], normalId)
			triangle(bottom[i], top[nextIndex], bottom[nextIndex], normalId)
		end
	end)
end

local function loadMesh()
	local fixed: EditableMesh? = nil
	local ok, part = pcall(EditableMeshBudget.withScratch, nil, function(scratch)
		writeMesh(scratch)
		fixed = EditableMeshBudget.fixed(scratch, nil, true)
		if fixed then
			return AssetService:CreateMeshPartAsync(Content.fromObject(fixed), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
		end
		return nil
	end)
	if not ok or not part then
		if fixed then fixed:Destroy() end
		if not ok then warn("[BaitCratePreview] Could not create crate mesh: " .. tostring(part)) end
		retryAt = os.clock() + 15
		return
	end
	part.Name = "CrateMesh"
	part.Anchored = true
	part.Color = Color3.new(1, 1, 1)
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new()
	template = part
end

function BaitCratePreview.show(parent: GuiObject, top: number): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.Name = "BaitCratePreview"
	view.BackgroundTransparency = 1
	view.Active = false
	view.AnchorPoint = Vector2.new(0.5, 0)
	view.Position = UDim2.new(0.5, 0, 0, top)
	view.Size = UDim2.fromOffset(88, 54)
	view.Ambient = rgb(177, 171, 158)
	view.LightColor = rgb(255, 240, 213)
	view.LightDirection = Vector3.new(-1, -2, -3)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 26
	camera.CFrame = CFrame.lookAt(Vector3.new(4.8, 3.65, 6.65), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = view
	local model = Instance.new("Model")
	model.Name = "BaitCrate"
	model.Parent = world
	view.Parent = parent

	if template then
		template:Clone().Parent = model
	else
		buildCrate(function(center, size, color)
			local part = Instance.new("Part")
			part.Anchored = true
			part.Size = size
			part.Position = center
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = model
		end)
		if MeshFeatures.EditableMeshesEnabled and os.clock() >= retryAt then
			waiting[model] = true
			if not loading then
				loading = true
				task.defer(function()
					loadMesh()
					if template then
						for pending in waiting do
							if pending.Parent then
								pending:ClearAllChildren()
								template:Clone().Parent = pending
							end
						end
					end
					table.clear(waiting)
					loading = false
				end)
			end
		end
	end
	return view
end

return BaitCratePreview
