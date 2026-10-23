-- Shows each island's coarse shell (server/Map/Lod) only while the real island is streamed out,
-- so distant islands stay visible without the client holding their full detail.
--
-- An island counts as loaded only while it actually has ground parts on this client. Going by the
-- island Model alone isn't enough: the instance can be around (arriving, or left behind after its
-- parts stream out) with nothing to draw, and hiding the shell then leaves a hole in the sea.

local Lod = {}

type Island = { model: Model, ground: number, connections: { RBXScriptConnection } }
type Shell = { parts: { BasePart }, hidden: boolean? }

function Lod.start()
	local map = workspace:WaitForChild("Map")
	local shells = map:WaitForChild("Lod")

	local byId: { [string]: Shell } = {}
	local islands: { [string]: Island } = {}
	local pending: { [string]: boolean } = {}

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
					for _, part in shell.parts do
						part.LocalTransparencyModifier = if hidden then 1 else 0
					end
				end
			end
		end)
	end

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
					if island.ground == 1 then
						refresh(id)
					end
				end
			end)
		)
		table.insert(
			island.connections,
			model.DescendantRemoving:Connect(function(d)
				if isGroundPart(model, d) then
					island.ground = math.max(island.ground - 1, 0)
					if island.ground == 0 then
						refresh(id)
					end
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
