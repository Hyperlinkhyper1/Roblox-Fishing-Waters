-- Shows each island's coarse shell (server/Map/Lod) only while the real island is streamed out,
-- so distant islands stay visible without the client holding their full detail.
--
-- An island counts as loaded only while it actually has ground parts on this client. Going by the
-- island Model alone isn't enough: the instance can be around (arriving, or left behind after its
-- parts stream out) with nothing to draw, and hiding the shell then leaves a hole in the sea.
--
-- Islands stream in piece by piece rather than as one atomic unit (that froze the frame), so a
-- shell gives way only once most of its island's ground has arrived. The home island is too big
-- to wait for whole, so its shell comes in tiles and each tile follows the ground under it.
--
-- Once a shell has given way it never comes back while its island is still in the world.
-- Bringing it back over missing parts flipped shells on and off over a fully drawn town, and a
-- shell the server swaps in later picks up where the one it replaces left off.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lod = {}

local FADE_TIME = 0.6
local PREFETCH_INTERVAL = 1
local PREFETCH_AHEAD = 400
local PREFETCH_STEP = 150 -- skip requests that barely move the streamed area
local TILE_LOADED = 0.85 -- share of a tile's ground that has to be in before its shell gives way
local ISLAND_LOADED = 0.95 -- the same for a whole island, which has no player inside it to cover gaps
local HANDOVER = 0.5 -- share of the ground that will do for a shell replacing one that had already given way
local TILE_NEAR = 96 -- streaming always holds the ground this close to the player
local TILE_INTERVAL = 0.5 -- how often tiles near the player are looked at again as they move

type Island = {
	model: Model,
	ground: number,
	parts: { [BasePart]: boolean },
	connections: { RBXScriptConnection },
	groundConnections: { RBXScriptConnection },
}
type Visual = { parts: { BasePart }, hidden: boolean? }
type Tile = Visual & { expected: number, loaded: number, minX: number, minZ: number }
type Grid = { size: number, x: number, z: number }
type Shell = Visual & {
	model: Model,
	connections: { RBXScriptConnection },
	needed: number, -- ground parts that have to be in before an untiled shell gives way
	inherited: boolean, -- replaced a shell that had already given way to the real island
	grid: Grid?, -- set when the shell is tiled
	tiles: { [string]: Tile },
	dirty: boolean, -- tile ground counts need redoing from scratch
}

local function disconnectAll(connections: { RBXScriptConnection })
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
end

local function halfExtent(part: BasePart): Vector3
	local frame, size = part.CFrame, part.Size / 2
	local right, up, back = frame.RightVector, frame.UpVector, frame.LookVector
	return Vector3.new(
		math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(back.X) * size.Z,
		math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(back.Y) * size.Z,
		math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(back.Z) * size.Z
	)
end

-- Every tile a part's footprint overlaps, keyed exactly as server/Map/Lod counted them.
local function tileKeys(part: BasePart, grid: Grid, callback: (string) -> ())
	local half, p = halfExtent(part), part.Position
	for x = math.floor((p.X - half.X - grid.x) / grid.size), math.floor((p.X + half.X - grid.x) / grid.size) do
		for z = math.floor((p.Z - half.Z - grid.z) / grid.size), math.floor((p.Z + half.Z - grid.z) / grid.size) do
			callback(x .. "," .. z)
		end
	end
end

local function playerPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

function Lod.start()
	local map = workspace:WaitForChild("Map")
	local shells = map:WaitForChild("Lod")

	local byId: { [string]: Shell } = {}
	local islands: { [string]: Island } = {}
	local pending: { [string]: boolean } = {}
	local fading: { [Visual]: number } = {}

	-- Ground parts an island needs before it counts as drawn. Tiled shells decide per tile,
	-- so for them any ground at all will do.
	local function needed(id: string): number
		local shell = byId[id]
		return if shell then shell.needed else 1
	end

	local function groundIn(id: string): number
		local island = islands[id]
		return if island and island.model:IsDescendantOf(workspace) then island.ground else 0
	end

	local function isTiled(id: string): boolean
		local shell = byId[id]
		return shell ~= nil and shell.grid ~= nil
	end

	-- Tracks how much of each tile's ground is here, as ground parts come and go.
	local function count(id: string, part: BasePart, delta: number)
		local shell = byId[id]
		local grid = shell and shell.grid
		if grid and not shell.dirty then
			tileKeys(part, grid, function(key)
				local tile = shell.tiles[key]
				if tile then
					tile.loaded += delta
				end
			end)
		end
	end

	local function recount(shell: Shell, id: string)
		shell.dirty = false
		for _, tile in shell.tiles do
			tile.loaded = 0
		end
		local island = islands[id]
		if island then
			for part in island.parts do
				count(id, part, 1)
			end
		end
	end

	local function show(visual: Visual, hidden: boolean)
		if visual.hidden == hidden then
			return
		end
		local first = visual.hidden == nil
		visual.hidden = hidden
		if hidden and not first then
			-- The real island is already drawn underneath, so the shell can melt away
			fading[visual] = os.clock()
		else
			-- Nothing else is there, so the shell has to be back this frame. A shell that arrives
			-- over an island that's already drawn goes straight away rather than flashing up.
			fading[visual] = nil
			for _, part in visual.parts do
				part.LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end

	-- Coalesce streaming bursts and only touch shell parts when visibility changes.
	-- Keep shells in their persistent container: reparenting whole islands tears down
	-- and recreates their workspace/render registrations on every transition.
	local function refresh(id: string)
		if pending[id] then
			return
		end
		pending[id] = true
		task.defer(function()
			pending[id] = nil
			local shell = byId[id]
			if not shell then
				return
			end
			local ground = groundIn(id)
			local grid = shell.grid
			if grid then
				if shell.dirty then
					recount(shell, id)
				end
				local focus = playerPosition()
				for _, tile in shell.tiles do
					local near = false
					if focus then
						local dx = math.max(tile.minX - focus.X, 0, focus.X - tile.minX - grid.size)
						local dz = math.max(tile.minZ - focus.Z, 0, focus.Z - tile.minZ - grid.size)
						near = dx * dx + dz * dz < TILE_NEAR * TILE_NEAR
					end
					-- Shells sit on top of the ground, so a half-streamed tile stays covered until it's
					-- nearly whole. Right around the player it's always real, never draped in shell.
					local share = if shell.inherited then HANDOVER else TILE_LOADED
					local whole = near or tile.loaded >= tile.expected * share
					show(tile, ground > 0 and (whole or tile.hidden == true))
				end
			else
				show(shell, ground > 0 and (ground >= shell.needed or shell.hidden == true))
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for visual, started in fading do
			local alpha = math.min((now - started) / FADE_TIME, 1)
			for _, part in visual.parts do
				part.LocalTransparencyModifier = alpha
			end
			if alpha >= 1 then
				fading[visual] = nil
			end
		end
	end)

	-- Ask for the water ahead of the boat early, so islands have time to stream in piece by piece
	-- before you sail up to them. Only while driving: on foot this kept dragging whole islands in
	-- around the harbour, which is memory the client then has to hold.
	task.spawn(function()
		local player = Players.LocalPlayer
		local lastRequest: Vector3? = nil
		while true do
			task.wait(PREFETCH_INTERVAL)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local seat = humanoid and humanoid.SeatPart
			if seat and seat:IsA("VehicleSeat") then
				local velocity = seat.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
				if velocity.Magnitude > 6 then
					local ahead = seat.Position + velocity.Unit * PREFETCH_AHEAD
					if not lastRequest or (ahead - lastRequest).Magnitude > PREFETCH_STEP then
						lastRequest = ahead
						pcall(player.RequestStreamAroundAsync, player, ahead, PREFETCH_INTERVAL * 4)
					end
				end
			end
		end
	end)

	-- Which tiles count as near changes as the player walks, without any ground streaming
	task.spawn(function()
		while true do
			task.wait(TILE_INTERVAL)
			for id in byId do
				if isTiled(id) then
					refresh(id)
				end
			end
		end
	end)

	-- The server swaps in a new shell (say, a tiled one for an older baked map) by replacing it
	-- The server destroys the old shell before parenting the new one, so remember for the
	-- replacement whether the island had already been drawn
	local gaveWay: { [string]: boolean } = {}
	local function forget(model: Instance)
		local shell = byId[model.Name]
		if shell and shell.model == model then
			local drawn = shell.hidden == true
			for _, tile in shell.tiles do
				drawn = drawn or tile.hidden == true
			end
			gaveWay[model.Name] = drawn or nil
			byId[model.Name] = nil
			disconnectAll(shell.connections)
			fading[shell] = nil
			for _, tile in shell.tiles do
				fading[tile] = nil
			end
		end
	end

	local function onShell(model: Instance)
		if not model:IsA("Model") then
			return
		end
		local old = byId[model.Name]
		if old then
			if old.model == model then
				return
			end
			forget(old.model)
		end

		local id = model.Name
		local inherited = gaveWay[id] == true
		gaveWay[id] = nil
		local size = model:GetAttribute("TileSize")
		local grid: Grid? = nil
		if typeof(size) == "number" then
			grid = {
				size = size,
				x = tonumber(model:GetAttribute("TileOriginX")) or 0,
				z = tonumber(model:GetAttribute("TileOriginZ")) or 0,
			}
		end
		local function groundNeeded(): number
			local ground = tonumber(model:GetAttribute("Ground"))
			local share = if inherited then HANDOVER else ISLAND_LOADED
			return if grid or not ground then 1 else math.max(math.ceil(ground * share), 1)
		end
		local shell: Shell = {
			model = model,
			parts = {},
			hidden = nil,
			connections = {},
			needed = groundNeeded(),
			inherited = inherited,
			grid = grid,
			tiles = {},
			dirty = grid ~= nil,
		}
		byId[id] = shell

		-- Untiled shells are one visual; tiled ones keep their parts in one Model per tile
		local function visualOf(d: Instance, create: boolean): Visual?
			if not grid then
				return shell
			end
			local tileModel = d.Parent
			if not tileModel or tileModel.Parent ~= model then
				return nil
			end
			local tile = shell.tiles[tileModel.Name]
			if not tile and create then
				local x, z = string.match(tileModel.Name, "^(-?%d+),(-?%d+)$")
				if not x or not z then
					return nil
				end
				tile = {
					parts = {},
					hidden = nil,
					expected = tonumber(tileModel:GetAttribute("Ground")) or 0,
					loaded = 0,
					minX = grid.x + (tonumber(x) :: number) * grid.size,
					minZ = grid.z + (tonumber(z) :: number) * grid.size,
				}
				shell.tiles[tileModel.Name] = tile
				-- The server recounts the ground under each tile at startup (see server/Map/Lod)
				local created = tile
				table.insert(
					shell.connections,
					tileModel:GetAttributeChangedSignal("Ground"):Connect(function()
						created.expected = tonumber(tileModel:GetAttribute("Ground")) or 0
						refresh(id)
					end)
				)
				-- Its ground may already be here; count everything again on the next refresh
				shell.dirty = true
				refresh(id)
			end
			return tile
		end
		local function onPart(d: Instance)
			if d:IsA("BasePart") then
				local visual = visualOf(d, true)
				if visual then
					table.insert(visual.parts, d)
					if visual.hidden ~= nil then
						d.LocalTransparencyModifier = if visual.hidden then 1 else 0
					end
				end
			end
		end
		table.insert(
			shell.connections,
			model:GetAttributeChangedSignal("Ground"):Connect(function()
				shell.needed = groundNeeded()
				refresh(id)
			end)
		)
		table.insert(shell.connections, model.DescendantAdded:Connect(onPart))
		table.insert(
			shell.connections,
			model.DescendantRemoving:Connect(function(d)
				if d:IsA("BasePart") then
					local visual = visualOf(d, false)
					local index = visual and table.find(visual.parts, d)
					if visual and index then
						table.remove(visual.parts, index)
					end
				end
			end)
		)
		for _, d in model:GetDescendants() do
			onPart(d)
		end
		refresh(id)
	end
	shells.ChildAdded:Connect(onShell)
	shells.ChildRemoved:Connect(forget)
	for _, shell in shells:GetChildren() do
		onShell(shell)
	end

	-- Only the Ground model's parts decide whether an island is drawn, so watch just that
	-- rather than every tree, prop and house part streaming onto the island.
	local function watchGround(island: Island, id: string, ground: Instance?)
		disconnectAll(island.groundConnections)
		island.ground = 0
		table.clear(island.parts)
		local shell = byId[id]
		if shell then
			shell.dirty = true
		end
		local function arrived(d: Instance)
			if d:IsA("BasePart") and not island.parts[d] then
				island.parts[d] = true
				island.ground += 1
				count(id, d, 1)
				-- Only the arrival that completes the island matters, so a streaming burst costs
				-- nothing. A tiled shell cares about every part, since each tile has its own count.
				if island.ground == needed(id) or isTiled(id) then
					refresh(id)
				end
			end
		end
		if ground then
			for _, d in ground:GetDescendants() do
				arrived(d)
			end
			table.insert(island.groundConnections, ground.DescendantAdded:Connect(arrived))
			table.insert(
				island.groundConnections,
				ground.DescendantRemoving:Connect(function(d)
					if d:IsA("BasePart") and island.parts[d] then
						island.parts[d] = nil
						island.ground -= 1
						count(id, d, -1)
						-- A shell that gave way only comes back once the island's ground is all gone
						if island.ground == 0 or isTiled(id) then
							refresh(id)
						end
					end
				end)
			)
		end
		refresh(id)
	end

	local function track(model: Model, id: string)
		local old = islands[id]
		if old and old.model == model then
			return
		end
		if old then
			disconnectAll(old.connections)
			disconnectAll(old.groundConnections)
		end

		local island: Island = { model = model, ground = 0, parts = {}, connections = {}, groundConnections = {} }
		islands[id] = island
		table.insert(
			island.connections,
			model.ChildAdded:Connect(function(child)
				if child.Name == "Ground" then
					watchGround(island, id, child)
				end
			end)
		)
		table.insert(
			island.connections,
			model.ChildRemoved:Connect(function(child)
				if child.Name == "Ground" then
					watchGround(island, id, model:FindFirstChild("Ground"))
				end
			end)
		)
		-- Covers the whole island leaving at once, whether it's destroyed or just unparented
		table.insert(
			island.connections,
			model.AncestryChanged:Connect(function()
				refresh(id)
			end)
		)
		watchGround(island, id, model:FindFirstChild("Ground"))
	end

	-- Islands are the models directly inside each biome folder (see server/Map/Lod). Listening
	-- there costs one call per island instead of one per part streaming into the map.
	local function onIsland(child: Instance)
		if not child:IsA("Model") then
			return
		end
		local id = child:GetAttribute("LodId")
		if id then
			track(child, tostring(id))
		else
			-- Islands generated after this client joined get their id once shells are built
			local connection
			connection = child:GetAttributeChangedSignal("LodId"):Connect(function()
				connection:Disconnect()
				onIsland(child)
			end)
		end
	end
	local function onFolder(folder: Instance)
		if folder:IsA("Folder") then
			folder.ChildAdded:Connect(onIsland)
			for _, child in folder:GetChildren() do
				onIsland(child)
			end
		end
	end
	map.ChildAdded:Connect(onFolder)
	for _, folder in map:GetChildren() do
		onFolder(folder)
	end
end

return Lod
