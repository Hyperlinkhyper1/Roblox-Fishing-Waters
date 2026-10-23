-- Native geometry shared by the supplied shop fixtures.
local ImportedModel = {}
local SKIN = 0.01

local function direction(v: Vector3): Vector3
	return Vector3.new(v.X, v.Z, -v.Y)
end

function ImportedModel.build(parent: Instance, frame: CFrame, geometry, options): Model
	local Geometry = geometry
	local scale = options.width / (Geometry.boundsMax.X - Geometry.boundsMin.X)
	local origin = options.origin
		or Vector3.new(
			(Geometry.boundsMin.X + Geometry.boundsMax.X) / 2,
			(Geometry.boundsMin.Y + Geometry.boundsMax.Y) / 2,
			Geometry.boundsMin.Z
		)
	local function point(v: Vector3): Vector3
		return direction(v - origin) * scale
	end
	local freezer = Instance.new("Model")
	freezer.Name = options.name
	freezer:SetAttribute("ModelVersion", options.version or 1)
	freezer:SetAttribute("SourceModel", options.sourceName)
	freezer:SetAttribute("SourceHash", Geometry.sourceHash)
	freezer:SetAttribute("SourceObjectCount", Geometry.sourceObjectCount or #Geometry.objects)
	freezer.Parent = parent

	local function part(kind: string, group: Model, size: Vector3, cf: CFrame, color: Color3): BasePart
		local finish = options.appearance and options.appearance[group.Name]
		local item = Instance.new(kind) :: BasePart
		item.Name = if kind == "Part" then "Solid" else "Surface"
		item.Size = size
		item.CFrame = frame * cf
		item.Color = if finish then finish.color else color
		item.Material = if finish then finish.material else Enum.Material.SmoothPlastic
		item.Transparency = if finish then finish.transparency or 0 else 0
		item.Reflectance = if finish then finish.reflectance or 0 else 0
		item.Anchored = true
		item.CanTouch = false
		item.CanCollide = options.canCollide ~= false
		item.TopSurface = Enum.SurfaceType.Smooth
		item.BottomSurface = Enum.SurfaceType.Smooth
		item.Parent = group
		return item
	end

	local vertices = {}
	for i, vertex in Geometry.vertices do
		vertices[i] = point(vertex)
	end
	for _, source in Geometry.objects do
		local group = Instance.new("Model")
		group.Name = source.name
		group:SetAttribute("SourceFaceCount", #source.faces)
		group:SetAttribute("SourceObject", source.sourceObject or source.name)
		-- Keep the supplied palette as metadata while allowing authored finishes.
		group:SetAttribute("SourceColor", source.color)
		group.Parent = freezer
		if source.box then
			local box = source.box
			local right = direction(box.right).Unit
			local back = right:Cross(direction(box.up)).Unit
			local up = back:Cross(right).Unit
			part("Part", group, box.size * scale, CFrame.fromMatrix(point(box.center), right, up, back), source.color)
			continue
		end
		local handled = {}
		for _, rectangle in source.rectangles or {} do
			local right, sourceUp = direction(rectangle.right).Unit, direction(rectangle.up).Unit
			local back = right:Cross(sourceUp).Unit
			local up = back:Cross(right).Unit
			local patch = part(
				"Part",
				group,
				Vector3.new(rectangle.size.X * scale, rectangle.size.Y * scale, SKIN),
				CFrame.fromMatrix(point(rectangle.center) - back * (SKIN / 2), right, up, back),
				source.color
			)
			patch.Name = "SurfacePatch"
			for _, faceIndex in rectangle.faces do
				handled[faceIndex] = true
			end
		end
		for faceIndex, face in source.faces do
			if handled[faceIndex] then
				continue
			end
			local a, b, c = vertices[face[1]], vertices[face[2]], vertices[face[3]]
			-- Source winding points out of the solid, including the recessed cavities.
			local cross = (b - a):Cross(c - a)
			if cross.Magnitude < 1e-12 then
				continue
			end
			local normal = cross.Unit
			local ab, ac, bc = b - a, c - a, c - b
			local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
			if abd > acd and abd > bcd then
				c, a = a, c
			elseif acd > bcd and acd > abd then
				a, b = b, a
			end
			ab, ac, bc = b - a, c - a, c - b
			local right = ac:Cross(ab).Unit
			local up, back = bc:Cross(right).Unit, bc.Unit
			local height = math.abs(ab:Dot(up))
			local shift = -normal * (SKIN / 2)
			local first, second = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
			-- Right triangles need one wedge. Skip the zero-area half instead of
			-- letting Roblox clamp it into a visible sliver.
			if first > 0.000001 then
				part(
					"WedgePart",
					group,
					Vector3.new(SKIN, math.max(height, 0.001), math.max(first, 0.001)),
					CFrame.fromMatrix((a + b) / 2 + shift, right, up, back),
					source.color
				)
			end
			if second > 0.000001 then
				part(
					"WedgePart",
					group,
					Vector3.new(SKIN, math.max(height, 0.001), math.max(second, 0.001)),
					CFrame.fromMatrix((a + c) / 2 + shift, -right, up, -back),
					source.color
				)
			end
		end
	end
	return freezer
end

return ImportedModel
