-- Far-away stand-ins for every island. Small islands stream as one atomic unit;
-- while they're out of streaming range the client shows a coarse faceted shell instead
-- (see client/Lod), so the whole map stays on the horizon for a fraction of the parts.
--
-- Shells are shrink-wrapped from the finished geometry: spherecasts on a polar lattice over
-- the island pick up the ground and any trees or buildings, so forests read as raised canopy.

local GeometryService = game:GetService("GeometryService")

local LowPoly = require(script.Parent.LowPoly)

local Lod = {}

local TAU = math.pi * 2
local SKY = 600 -- spherecasts are capped at 1024 studs, so start low enough to reach the seabed
local WATERLINE = 0.3 -- triangles entirely below this are hidden by the sea anyway
local UNDERWATER = -4 -- coast vertices sink to here so shores slope into the water

type Sample = { position: Vector3, color: Color3?, material: Enum.Material? }

local function halfExtent(part: BasePart): Vector3
	local frame, size = part.CFrame, part.Size / 2
	local right, up, back = frame.RightVector, frame.UpVector, frame.LookVector
	return Vector3.new(
		math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(back.X) * size.Z,
		math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(back.Y) * size.Z,
		math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(back.Z) * size.Z
	)
end

local function opaqueParts(model: Model): { BasePart }
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.5 and d.Material ~= Enum.Material.Neon then
			if d.Position.Y + halfExtent(d).Y > UNDERWATER then
				table.insert(parts, d)
			end
		end
	end
	return parts
end

local function sample(params: RaycastParams, x: number, z: number, radius: number): Sample
	local hit = workspace:Spherecast(Vector3.new(x, SKY, z), radius, Vector3.new(0, -1000, 0), params)
	if hit and hit.Position.Y > UNDERWATER then
		local p = hit.Instance :: BasePart
		return { position = Vector3.new(x, hit.Position.Y, z), color = p.Color, material = p.Material }
	end
	return { position = Vector3.new(x, UNDERWATER, z) }
end

local function face(a: Sample, b: Sample, c: Sample, parent: Instance)
	local pa, pb, pc = a.position, b.position, c.position
	local top = a
	for _, s in { b, c } do
		if s.position.Y > top.position.Y then
			top = s
		end
	end
	if top.position.Y < WATERLINE or not top.material then
		return
	end

	local r, g, bl, n = 0, 0, 0, 0
	for _, s in { a, b, c } do
		if s.color then
			r, g, bl, n = r + s.color.R, g + s.color.G, bl + s.color.B, n + 1
		end
	end
	local centroid = (pa + pb + pc) / 3
	LowPoly.triangle(
		pa,
		pb,
		pc,
		centroid - Vector3.new(0, 100, 0),
		Color3.new(r / n, g / n, bl / n),
		parent,
		top.material
	)
end

local function shell(island: Model, parent: Instance): Model
	-- Offshore slopes can be much wider than a small rock. Build its distant
	-- silhouette from the visible island rather than its submerged footprint.
	local parts = opaqueParts(island)
	if #parts == 0 then
		local empty = Instance.new("Model")
		empty.Name = tostring(island:GetAttribute("LodId"))
		empty.Parent = parent
		return empty
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, part in parts do
		local half = halfExtent(part)
		minX, maxX = math.min(minX, part.Position.X - half.X), math.max(maxX, part.Position.X + half.X)
		minZ, maxZ = math.min(minZ, part.Position.Z - half.Z), math.max(maxZ, part.Position.Z + half.Z)
	end
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local extent = math.max(maxX - minX, maxZ - minZ) / 2

	-- Coarser than the real thing on both axes; small rocks collapse to a single cone.
	local segments = math.clamp(math.round(extent / 14), 5, 24)
	local rings = math.clamp(math.round(extent / 70), 1, 6)
	local spacing = extent / rings

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	local radius = math.clamp(spacing * 0.35, 2, 16)

	local model = Instance.new("Model")
	model.Name = tostring(island:GetAttribute("LodId"))

	local center = sample(params, cx, cz, radius)
	local lattice: { { Sample } } = {}
	for i = 1, rings do
		local ring = {}
		local r = spacing * i
		for j = 1, segments do
			-- Alternate rings are half a step out of phase so the facets don't line up into spokes
			local angle = (j - 1 + (i % 2) * 0.5) / segments * TAU
			ring[j] = sample(params, cx + math.cos(angle) * r, cz + math.sin(angle) * r, radius)
		end
		lattice[i] = ring
	end

	for j = 1, segments do
		local k = j % segments + 1
		face(center, lattice[1][j], lattice[1][k], model)
		for i = 1, rings - 1 do
			local inner, outer = lattice[i], lattice[i + 1]
			-- Whichever ring is half a step ahead decides which way the strip's diagonals lean
			if i % 2 == 0 then
				face(inner[j], outer[j], inner[k], model)
				face(inner[k], outer[j], outer[k], model)
			else
				face(inner[j], outer[j], outer[k], model)
				face(inner[j], outer[k], inner[k], model)
			end
		end
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	model.Parent = parent
	return model
end

-- Welds a shell's wedges into one union. The renderer stops drawing small parts on the horizon
-- whenever graphics quality steps down (automatic quality does that on every frame-rate dip),
-- which blinked whole shells out of the sea; a single island-sized part survives that culling.
local function merge(model: Instance)
	local parts = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts < 2 then
		return
	end
	local others = table.move(parts, 2, #parts, 1, {})
	local ok, result = pcall(GeometryService.UnionAsync, GeometryService, parts[1], others, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
		SplitApart = false,
	})
	if not ok or not result[1] then
		-- The loose wedges still work as a shell, just one that culls more eagerly
		warn(string.format("[Lod] Could not merge shell %s: %s", model.Name, tostring(result)))
		return
	end
	local union = result[1] :: BasePart
	union.Name = "Shell"
	union.Anchored = true
	union.CanCollide = false
	union.CanQuery = false
	union.CanTouch = false
	union.CastShadow = false
	union.Parent = model
	for _, part in parts do
		part:Destroy()
	end
end

local function mergeAll(container: Instance)
	for _, model in container:GetChildren() do
		merge(model)
		task.wait()
	end
end

-- Islands are the models directly inside each biome folder that have a Ground mesh.
local function islands(root: Instance): { Model }
	local found = {}
	for _, folder in root:GetChildren() do
		if folder:IsA("Folder") then
			for _, child in folder:GetChildren() do
				if child:IsA("Model") and child:FindFirstChild("Ground") then
					table.insert(found, child)
				end
			end
		end
	end
	return found
end

-- The home island contains a whole town. Requiring every house, tree and beach prop
-- to arrive as one atomic model delays joining even on fast PCs. Its local ground
-- streams normally; the client already keeps the shell until ground actually arrives.
function Lod.prepareIsland(island: Model)
	island.ModelStreamingMode = if island.Name == "Harbour Isle"
		then Enum.ModelStreamingMode.Default
		else Enum.ModelStreamingMode.Atomic
end

function Lod.prepareStreaming(root: Instance)
	local shells = root:FindFirstChild("Lod")
	if shells and shells:IsA("Model") then
		-- Apply to baked maps too, so distant stand-ins cannot stream out/reload.
		shells.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	for _, island in islands(root) do
		Lod.prepareIsland(island)
	end
end

-- Builds shells under root.Lod if they aren't already baked in. Small islands
-- stream as a whole, so the client never sees half an island next to its shell.
function Lod.build(root: Instance)
	Lod.prepareStreaming(root)
	local baked = root:FindFirstChild("Lod")
	if baked then
		-- Shells baked before they were merged still arrive as loose wedges
		mergeAll(baked)
		return
	end
	local started = os.clock()

	local container = Instance.new("Model")
	container.Name = "Lod"
	container.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local parts = 0
	for id, island in islands(root) do
		island:SetAttribute("LodId", id)
		parts += #shell(island, container):GetChildren()
		-- Generation may continue after the harbour opens. Share the scheduler
		-- after each shell instead of blocking live players for twenty islands.
		task.wait()
	end
	container.Parent = root
	-- Merge once the shells are in the world, so CSG runs on parts it can see
	mergeAll(container)

	print(string.format("[Lod] Built %d shell parts in %.1fs", parts, os.clock() - started))
end

return Lod
