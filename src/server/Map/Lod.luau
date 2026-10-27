-- Far-away stand-ins for every island. Islands stream in piece by piece; until one has
-- arrived the client shows a coarse faceted shell instead (see client/Lod), so the whole
-- map stays on the horizon for a fraction of the parts.
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

-- How many ground parts the client has to receive before an untiled shell gives way
local function groundCount(island: Model): number
	local ground = island:FindFirstChild("Ground")
	local count = 0
	for _, d in if ground then ground:GetDescendants() else {} do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- Ground parts under each tile of a tiled shell, so the client can tell when a tile's real ground is in
local function countTiles(model: Instance, island: Model)
	local originX, originZ = model:GetAttribute("TileOriginX") or 0, model:GetAttribute("TileOriginZ") or 0
	local counts: { [string]: number } = {}
	local ground = island:FindFirstChild("Ground")
	for _, d in if ground then ground:GetDescendants() else {} do
		if d:IsA("BasePart") then
			tileKeys(d, originX, originZ, function(key)
				counts[key] = (counts[key] or 0) + 1
			end)
		end
	end
	for _, tile in model:GetChildren() do
		local count = counts[tile.Name] or 0
		if tile:GetAttribute("Ground") ~= count then
			tile:SetAttribute("Ground", count)
		end
	end
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

	for _, tile in tiles do
		if #tile:GetChildren() == 0 then
			tile:Destroy()
		end
	end
	countTiles(model, island)
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
			model:SetAttribute("Ground", groundCount(island))
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

-- Every island is cut into pieces that stream in one at a time and are then pinned for the
-- player they reached (see Lod.serve), so once an island is drawn it never streams back out
-- and reloads. Plain streaming couldn't promise that: with StreamOutBehavior LowMemory the
-- client throws out everything past StreamingMinRadius whenever the device runs short of
-- memory, which reloaded the harbour over and over. Pinning a whole island instead meant
-- it arrived as one atomic unit, thousands of wedges created in a single frame, which froze
-- the game every time one came into range. A piece is small enough to arrive without a hitch.
-- PersistentPerPlayer behaves as Atomic until the server adds the player, then as Persistent.
local PIECE_TAG = "LodPiece"
local PIECE_PARTS = 200 -- models up to this size stream in as one piece; bigger ones are split
local CHUNK = 96 -- loose ground wedges are regrouped into square chunks this wide
local PIN_BATCH = 500 -- most pieces one request may pin

local pieces: { [number]: Model } = {}
local pieceIds: { [Model]: number } = {}
local split: { [Model]: boolean } = {}
local lastId = 0

-- Ids are handed out afresh every server start; ones baked into a saved map are replaced.
local function addPiece(model: Model)
	if pieceIds[model] then
		return
	end
	lastId += 1
	local id = lastId
	pieces[id] = model
	pieceIds[model] = id
	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model:SetAttribute("PieceId", id)
	model:AddTag(PIECE_TAG)
end

-- BaseParts under a model, or nil when it holds a model that streams by rules of its own
local function plainParts(model: Model): number?
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		elseif d:IsA("Model") and d.ModelStreamingMode ~= Enum.ModelStreamingMode.Default then
			return nil
		end
	end
	return count
end

-- Ground is thousands of anonymous wedges loose in one model (and its seabed slope), so it
-- is regrouped by position. Nothing looks ground wedges up by name.
local function chunkGround(container: Instance)
	local chunks: { [string]: Model } = {}
	for _, child in container:GetChildren() do
		if child:IsA("BasePart") then
			local key = math.floor(child.Position.X / CHUNK) .. "," .. math.floor(child.Position.Z / CHUNK)
			local chunk = chunks[key]
			if not chunk then
				chunk = Instance.new("Model")
				chunk.Name = "GroundChunk"
				addPiece(chunk)
				chunks[key] = chunk
			end
			child.Parent = chunk
		elseif child:IsA("Model") then
			if child:HasTag(PIECE_TAG) then
				addPiece(child)
			else
				chunkGround(child)
			end
		end
	end
	for _, chunk in chunks do
		chunk.Parent = container
	end
end

-- A player base is too big for one piece, but splitting it left its quay, deck and other loose
-- parts streaming normally, and the code that finds them by name under the base stops it
-- being regrouped. So a base is pinned whole; pieces baked inside one by older maps go back
-- to plain models, or their stale ids would pin the wrong pieces.
local BASE_TAG = "PlayerBase"

local function pinWhole(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:HasTag(PIECE_TAG) then
			d:RemoveTag(PIECE_TAG)
			d:SetAttribute("PieceId", nil)
			d.ModelStreamingMode = Enum.ModelStreamingMode.Default
		end
	end
	addPiece(model)
end

-- Everything else keeps its place in the hierarchy: a model small enough becomes a piece as
-- it is, a bigger one is split into its children. Loose parts in a big model stay as they
-- were and still stream normally.
local function splitIntoPieces(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			local mode = child.ModelStreamingMode
			if child:HasTag(BASE_TAG) then
				pinWhole(child)
			elseif child:HasTag(PIECE_TAG) or mode == Enum.ModelStreamingMode.Atomic then
				-- An atomic model (a shop, say) already arrives whole, so pinning changes nothing else
				addPiece(child)
			elseif mode == Enum.ModelStreamingMode.Default then
				local parts = plainParts(child)
				if parts and parts <= PIECE_PARTS then
					addPiece(child)
				else
					splitIntoPieces(child)
				end
			end
		elseif child:IsA("Folder") then
			splitIntoPieces(child)
		end
	end
end

-- Must run before an island's contents first replicate: switching a model's streaming mode
-- after clients have it makes it stream in all over again. So each island is split once,
-- either as it's generated or at startup before anyone has a character.
local function splitIsland(island: Model)
	if split[island] then
		return
	end
	split[island] = true
	island.ModelStreamingMode = Enum.ModelStreamingMode.Default
	for _, child in island:GetChildren() do
		if child:IsA("Model") and child.Name == "Ground" and not child:HasTag(PIECE_TAG) then
			chunkGround(child)
		end
	end
	splitIntoPieces(island)
end

-- Called as a generated island is parented. Its trees and houses are added after that, so
-- each is split as it goes in, in the same frame and so before it first replicates.
function Lod.prepareIsland(island: Model)
	if split[island] then
		return
	end
	splitIsland(island)
	island.ChildAdded:Connect(function(child)
		if child:IsA("Model") and child.ModelStreamingMode == Enum.ModelStreamingMode.Default then
			local parts = plainParts(child)
			if parts and parts <= PIECE_PARTS then
				addPiece(child)
			else
				splitIntoPieces(child)
			end
		end
	end)
end

-- Clients report each piece as it streams in (see client/Lod) and the server pins it for
-- them. Pins last for the session: a player who sails the whole map ends up holding all of it.
function Lod.serve()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	if ReplicatedStorage:FindFirstChild("LodPin") then
		return
	end
	local Players = game:GetService("Players")
	local pinned: { [Player]: { [number]: boolean } } = {}
	Players.PlayerRemoving:Connect(function(player)
		pinned[player] = nil
	end)

	local remote = Instance.new("RemoteEvent")
	remote.Name = "LodPin"
	remote.OnServerEvent:Connect(function(player, ids)
		if typeof(ids) ~= "table" then
			return
		end
		local held = pinned[player]
		if not held then
			held = {}
			pinned[player] = held
		end
		for i, id in ids do
			if typeof(i) ~= "number" or i > PIN_BATCH then
				break
			end
			local piece = if typeof(id) == "number" then pieces[id] else nil
			if piece and not held[id] then
				if not piece.Parent then
					pieces[id], pieceIds[piece] = nil, nil
				elseif piece.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer then
					held[id] = true
					piece:AddPersistentPlayer(player)
				end
			end
		end
	end)
	remote.Parent = ReplicatedStorage
end

function Lod.prepareStreaming(root: Instance)
	local shells = root:FindFirstChild("Lod")
	if shells and shells:IsA("Model") then
		-- Apply to baked maps too, so distant stand-ins cannot stream out/reload.
		shells.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	for _, island in islands(root) do
		splitIsland(island)
		-- A generated harbour parents its empty Bases folder before building the bases in it,
		-- so the island's ChildAdded split never saw them
		for _, d in island:GetDescendants() do
			if d:IsA("Model") and d:HasTag(BASE_TAG) and not pieceIds[d] then
				pinWhole(d)
			end
		end
		-- Counts baked into a saved map go stale whenever startup repairs rebuild some ground
		-- (the harbour's drydock channel, say). A tile waiting for ground that no longer exists
		-- stayed up over the finished town, so count again from the ground as it is now.
		local id = island:GetAttribute("LodId")
		local shell = if shells and id ~= nil then shells:FindFirstChild(tostring(id)) else nil
		if shell and shell:GetAttribute("TileSize") then
			countTiles(shell, island)
		elseif shell then
			-- An untiled home shell is only a stand-in until Lod.build tiles it; don't make it
			-- wait for the whole town, or it sits over the harbour until the swap
			local count = if tiled(island) then 1 else groundCount(island)
			if shell:GetAttribute("Ground") ~= count then
				shell:SetAttribute("Ground", count)
			end
		end
	end
end

-- Builds shells under root.Lod if they aren't already baked in. The client keeps a shell
-- over its island until the island has mostly streamed in, so half an island never shows.
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
				-- This runs on every server start until a map with the tiled shell is saved
				print("[Lod] Rebuilding the untiled " .. island.Name .. " shell; save the map to skip this")
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
