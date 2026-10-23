-- Shows each island's coarse shell (server/Map/Lod) only while the real island is streamed out,
-- so distant islands stay visible without the client holding their full detail.
--
-- An island counts as loaded only while it actually has ground parts on this client. Going by the
-- island Model alone isn't enough: the instance can be around (arriving, or left behind after its
-- parts stream out) with nothing to draw, and hiding the shell then leaves a hole in the sea.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lod = {}

local FADE_TIME = 0.6
local PREFETCH_INTERVAL = 1
local PREFETCH_AHEAD = 400
local PREFETCH_STEP = 150 -- skip requests that barely move the streamed area

type Island = {
	model: Model,
	ground: number,
	connections: { RBXScriptConnection },
	groundConnections: { RBXScriptConnection },
}
type Shell = { parts: { BasePart }, hidden: boolean? }

local function disconnectAll(connections: { RBXScriptConnection })
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
end

function Lod.start()
	local map = workspace:WaitForChild("Map")
	local shells = map:WaitForChild("Lod")

	local byId: { [string]: Shell } = {}
	local islands: { [string]: Island } = {}
	local pending: { [string]: boolean } = {}
	local fading: { [Shell]: number } = {}

	local function isLoaded(id: string): boolean
		local island = islands[id]
		return island ~= nil and island.ground > 0 and island.model:IsDescendantOf(workspace)
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
			if shell then
				local hidden = isLoaded(id)
				if shell.hidden ~= hidden then
					shell.hidden = hidden
					if hidden then
						-- The real island is already drawn underneath, so the shell can melt away
						fading[shell] = os.clock()
					else
						-- Nothing else is there, so the shell has to be back this frame
						fading[shell] = nil
						for _, part in shell.parts do
							part.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end)
	end

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for shell, started in fading do
			local alpha = math.min((now - started) / FADE_TIME, 1)
			for _, part in shell.parts do
				part.LocalTransparencyModifier = alpha
			end
			if alpha >= 1 then
				fading[shell] = nil
			end
		end
	end)

	-- Ask for the water ahead of the boat early, so you sail up to real islands rather than shells.
	-- Only while driving: on foot this kept dragging whole islands in around the harbour, and
	-- every atomic island that arrives is a frame hitch (and memory that later has to stream out).
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

	local function onShell(shell: Instance)
		if shell:IsA("Model") and not byId[shell.Name] then
			local entry: Shell = { parts = {}, hidden = nil }
			byId[shell.Name] = entry
			local function onPart(d: Instance)
				if d:IsA("BasePart") then
					table.insert(entry.parts, d)
					if entry.hidden ~= nil then
						d.LocalTransparencyModifier = if entry.hidden then 1 else 0
					end
				end
			end
			shell.DescendantAdded:Connect(onPart)
			shell.DescendantRemoving:Connect(function(d)
				if d:IsA("BasePart") then
					local index = table.find(entry.parts, d)
					if index then
						table.remove(entry.parts, index)
					end
				end
			end)
			for _, d in shell:GetDescendants() do
				onPart(d)
			end
			refresh(shell.Name)
		end
	end
	shells.ChildAdded:Connect(onShell)
	for _, shell in shells:GetChildren() do
		onShell(shell)
	end

	-- Only the Ground model's parts decide whether an island is drawn, so watch just that
	-- rather than every tree, prop and house part streaming onto the island.
	local function watchGround(island: Island, id: string, ground: Instance?)
		disconnectAll(island.groundConnections)
		island.ground = 0
		if ground then
			for _, d in ground:GetDescendants() do
				if d:IsA("BasePart") then
					island.ground += 1
				end
			end
			table.insert(
				island.groundConnections,
				ground.DescendantAdded:Connect(function(d)
					if d:IsA("BasePart") then
						island.ground += 1
						if island.ground == 1 then
							refresh(id)
						end
					end
				end)
			)
			table.insert(
				island.groundConnections,
				ground.DescendantRemoving:Connect(function(d)
					if d:IsA("BasePart") then
						island.ground = math.max(island.ground - 1, 0)
						if island.ground == 0 then
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

		local island: Island = { model = model, ground = 0, connections = {}, groundConnections = {} }
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
