-- Shows each island's coarse shell (server/Map/Lod) only while the real island is streamed out,
-- so distant islands stay visible without the client holding their full detail.
--
-- An island counts as loaded only while it actually has ground parts on this client. Going by the
-- island Model alone isn't enough: the instance can be around (arriving, or left behind after its
-- parts stream out) with nothing to draw, and hiding the shell then leaves a hole in the sea.

local Lod = {}

type Island = { model: Model, ground: number, connections: { RBXScriptConnection } }

function Lod.start()
	local map = workspace:WaitForChild("Map")
	local shells = map:WaitForChild("Lod")

	local byId: { [string]: Model } = {}
	local islands: { [string]: Island } = {}

	local function isLoaded(id: string): boolean
		local island = islands[id]
		return island ~= nil and island.ground > 0 and island.model:IsDescendantOf(workspace)
	end

	-- Deferred because these run inside ancestry-change events, where reparenting is refused.
	-- The state is read when the deferred call runs, so a burst of changes settles on the latest.
	local function refresh(id: string)
		task.defer(function()
			local shell = byId[id]
			if shell then
				local parent = if isLoaded(id) then nil else shells
				if shell.Parent ~= parent then
					shell.Parent = parent
				end
			end
		end)
	end

	local function onShell(shell: Instance)
		if shell:IsA("Model") and not byId[shell.Name] then
			byId[shell.Name] = shell
			refresh(shell.Name)
		end
	end
	shells.ChildAdded:Connect(onShell)
	for _, shell in shells:GetChildren() do
		onShell(shell)
	end

	local function isGroundPart(island: Model, d: Instance): boolean
		local ground = island:FindFirstChild("Ground")
		return d:IsA("BasePart") and ground ~= nil and d:IsDescendantOf(ground)
	end

	local function track(model: Model, id: string)
		local old = islands[id]
		if old and old.model == model then
			return
		end
		if old then
			for _, c in old.connections do
				c:Disconnect()
			end
		end

		local island: Island = { model = model, ground = 0, connections = {} }
		islands[id] = island
		for _, d in model:GetDescendants() do
			if isGroundPart(model, d) then
				island.ground += 1
			end
		end
		table.insert(
			island.connections,
			model.DescendantAdded:Connect(function(d)
				if isGroundPart(model, d) then
					island.ground += 1
					refresh(id)
				end
			end)
		)
		table.insert(
			island.connections,
			model.DescendantRemoving:Connect(function(d)
				if isGroundPart(model, d) then
					island.ground = math.max(island.ground - 1, 0)
					refresh(id)
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
		refresh(id)
	end

	local function islandId(instance: Instance): string?
		local id = instance:IsA("Model") and instance:GetAttribute("LodId")
		return if id then tostring(id) else nil
	end

	map.DescendantAdded:Connect(function(d)
		local id = islandId(d)
		if id then
			track(d :: Model, id)
		end
	end)
	for _, d in map:GetDescendants() do
		local id = islandId(d)
		if id then
			track(d :: Model, id)
		end
	end
end

return Lod
