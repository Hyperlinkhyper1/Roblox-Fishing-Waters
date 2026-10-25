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
-- The home island streams in pieces (see Lod.prepareIsland), so its shell is cut into square
-- tiles the client swaps one at a time. Tiles follow the lattice lines, so their seams close.
local TILE = 192
local TILE_STEP = 48

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

-- Every tile a part's footprint overlaps; client/Lod keys the parts it receives the same way.
local function tileKeys(part: BasePart, originX: number, originZ: number, callback: (string) -> ())
	local half, p = halfExtent(part), part.Position
	for x = math.floor((p.X - half.X - originX) / TILE), math.floor((p.X + half.X - originX) / TILE) do
		for z = math.floor((p.Z - half.Z - originZ) / TILE), math.floor((p.Z + half.Z - originZ) / TILE) do
			callback(x .. "," .. z)
		end
	end
end

local function tiled(island: Model): boolean
	return island.Name == "Harbour Isle"
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

local function bounds(parts: { BasePart }): (number, number, number, number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, part in parts do
		local half = halfExtent(part)
		minX, maxX = math.min(minX, part.Position.X - half.X), math.max(maxX, part.Position.X + half.X)
		minZ, maxZ = math.min(minZ, part.Position.Z - half.Z), math.max(maxZ, part.Position.Z + half.Z)
	end
	return minX, maxX, minZ, maxZ
end

local function inert(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
end

local function radialShell(model: Model, parts: { BasePart })
	local minX, maxX, minZ, maxZ = bounds(parts)
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
end

-- A square lattice cut into tiles. Each tile records how many ground parts lie under it,
-- so the client can tell when enough of the real ground has streamed in to replace it.
local function tiledShell(model: Model, island: Model, parts: { BasePart })
	local minX, maxX, minZ, maxZ = bounds(parts)
	local originX, originZ = math.floor(minX / TILE) * TILE, math.floor(minZ / TILE) * TILE
	model:SetAttribute("TileSize", TILE)
	model:SetAttribute("TileOriginX", originX)
	model:SetAttribute("TileOriginZ", originZ)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	local radius = math.clamp(TILE_STEP * 0.35, 2, 16)

	local cols, rows = math.ceil((maxX - originX) / TILE_STEP), math.ceil((maxZ - originZ) / TILE_STEP)
	local lattice: { { Sample } } = {}
	for i = 0, cols do
		local column = {}
		for k = 0, rows do
			column[k] = sample(params, originX + i * TILE_STEP, originZ + k * TILE_STEP, radius)
		end
		lattice[i] = column
		if i % 8 == 0 then
			task.wait()
		end
	end

	local per = TILE // TILE_STEP
	local tiles: { [string]: Model } = {}
	for i = 0, cols - 1 do
		for k = 0, rows - 1 do
			local key = (i // per) .. "," .. (k // per)
			local tile = tiles[key]
			if not tile then
				tile = Instance.new("Model")
				tile.Name = key
				tile.Parent = model
				tiles[key] = tile
			end
			local a, b, c, d = lattice[i][k], lattice[i + 1][k], lattice[i][k + 1], lattice[i + 1][k + 1]
			if (i + k) % 2 == 0 then
				face(a, b, c, tile)
				face(b, d, c, tile)
			else
				face(a, b, d, tile)
				face(a, d, c, tile)
			end
		end
	end

	local counts: { [string]: number } = {}
	local ground = island:FindFirstChild("Ground")
	for _, d in if ground then ground:GetDescendants() else {} do
		if d:IsA("BasePart") then
			tileKeys(d, originX, originZ, function(key)
				counts[key] = (counts[key] or 0) + 1
			end)
		end
	end
	for key, tile in tiles do
		if #tile:GetChildren() == 0 then
			tile:Destroy()
		else
			tile:SetAttribute("Ground", counts[key] or 0)
		end
	end
end

-- Built unparented: it only goes into the world once merged (see merge).
local function shell(island: Model): Model
	local model = Instance.new("Model")
	model.Name = tostring(island:GetAttribute("LodId"))
	-- Offshore slopes can be much wider than a small rock. Build its distant
	-- silhouette from the visible island rather than its submerged footprint.
	local parts = opaqueParts(island)
	if #parts > 0 then
		if tiled(island) then
			tiledShell(model, island, parts)
		else
			radialShell(model, parts)
		end
		inert(model)
	end
	return model
end

-- Welds a shell's wedges into one union. The renderer stops drawing small parts on the horizon
-- whenever graphics quality steps down (automatic quality does that on every frame-rate dip),
-- which blinked whole shells out of the sea; a single island-sized part survives that culling.
-- GeometryService works on unparented parts, so new shells replicate as finished unions
-- instead of thousands of wedges that every client receives only to drop them again.
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

local function mergeShell(model: Instance)
	if model:GetAttribute("TileSize") then
		for _, tile in model:GetChildren() do
			merge(tile)
			task.wait()
		end
	else
		merge(model)
	end
end

local function mergeAll(container: Instance)
	for _, model in container:GetChildren() do
		mergeShell(model)
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
-- Every other island arrives atomically the first time, then is pinned for that player
-- (see Lod.start) so it never streams out and back in again.
function Lod.prepareIsland(island: Model)
	island.ModelStreamingMode = if tiled(island)
		then Enum.ModelStreamingMode.Default
		else Enum.ModelStreamingMode.PersistentPerPlayer
end

-- Closed-off buildings (the rod and furniture stores) stand away from the map under
-- workspace.Interiors. The drydock and player bases are open to the sea, so they aren't there.
local function insideClosedBuilding(player: Player): boolean
	local character = player.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	local interiors = workspace:FindFirstChild("Interiors")
	if not body or not body:IsA("BasePart") or not interiors then
		return false
	end
	for _, hall in interiors:GetChildren() do
		local frame, size = hall:GetAttribute("InteriorFrame"), hall:GetAttribute("InteriorSize")
		if typeof(frame) == "CFrame" and typeof(size) == "Vector3" then
			local position = frame:PointToObjectSpace(body.Position)
			if
				math.abs(position.X) <= size.X / 2
				and math.abs(position.Y) <= size.Y / 2
				and math.abs(position.Z) <= size.Z / 2
			then
				return true
			end
		end
	end
	return false
end

-- Clients report each island once its ground first arrives; from then on it stays
-- loaded for them, so islands never swap back to shells and reload. The one exception
-- is inside a closed building, where none of the sea is visible: there the pins are
-- released so the client may stream islands out, and it re-pins whatever is still
-- loaded when the player steps back outside.
function Lod.start(root: Instance)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local remotes = Instance.new("Folder")
	remotes.Name = "Lod"
	local keep = Instance.new("RemoteEvent")
	keep.Name, keep.Parent = "Keep", remotes
	remotes.Parent = ReplicatedStorage

	local pinned: { [Player]: { [string]: Model } } = {}
	local inside: { [Player]: boolean } = {}
	Players.PlayerRemoving:Connect(function(player)
		pinned[player] = nil
		inside[player] = nil
	end)
	keep.OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" or inside[player] then
			return
		end
		local held = pinned[player]
		if not held then
			held = {}
			pinned[player] = held
		end
		if held[id] then
			return
		end
		for _, island in islands(root) do
			if tostring(island:GetAttribute("LodId")) == id then
				if island.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer then
					held[id] = island
					island:AddPersistentPlayer(player)
				end
				return
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local now = insideClosedBuilding(player)
				if now == (inside[player] == true) then
					continue
				end
				inside[player] = now or nil
				if now then
					for _, island in pinned[player] or {} do
						if island.Parent then
							island:RemovePersistentPlayer(player)
						end
					end
					pinned[player] = nil
					keep:FireClient(player, "Release")
				else
					keep:FireClient(player, "Resume")
				end
			end
		end
	end)
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
		-- Maps baked before the home island's shell came in tiles get a tiled one; the old
		-- single shell vanished at the island's first ground part and left the rest missing
		for _, island in islands(root) do
			local id = island:GetAttribute("LodId")
			local old = if id ~= nil then baked:FindFirstChild(tostring(id)) else nil
			if id ~= nil and tiled(island) and not (old and old:GetAttribute("TileSize")) then
				local replacement = shell(island)
				mergeShell(replacement)
				if old then
					old:Destroy()
				end
				replacement.Parent = baked
			end
		end
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
		local model = shell(island)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		mergeShell(model)
		model.Parent = container
		-- Generation may continue after the harbour opens. Share the scheduler
		-- after each shell instead of blocking live players for twenty islands.
		task.wait()
	end
	container.Parent = root

	print(string.format("[Lod] Built %d shell parts in %.1fs", parts, os.clock() - started))
end

return Lod
