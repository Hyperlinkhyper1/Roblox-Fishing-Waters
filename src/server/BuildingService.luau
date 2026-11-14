-- Owner-authoritative structural editing. Geometry is only changed after the
-- wallet transaction commits; every command is rechecked inside that save.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatService = require(script.Parent.BoatService)
local Building = require(ReplicatedStorage.Shared.BuildingCatalog)
local Renderer = require(ReplicatedStorage.Shared.BuildingRenderer)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)

local Service = {}
local started = false
local requests, busy, histories = {}, {}, {}
local paintRequests = {}
local watched, queued, applied = {}, {}, {}
local update: RemoteEvent
local HISTORY_LIMIT = 20
local BATCH_LIMIT = 64

local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = clone(child) end
	return result
end

local function same(a, b): boolean
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end

local function empty()
	return { NextId = 1, Pieces = {}, Overrides = {} }
end

local function siteData(profile, site)
	return if profile and profile.Angler.Building then profile.Angler.Building[site] or empty() else empty()
end

local function modelOf(player: Player, site: string): (Model?, CFrame?)
	local tag = if site == "Company" then "CompanyIsland" else "PlayerBase"
	for _, plot in CollectionService:GetTagged(tag) do
		if not plot:IsA("Model") or not plot:IsDescendantOf(workspace)
			or plot:GetAttribute("OwnerUserId") ~= player.UserId then continue end
		local model = if site == "Company" then plot else plot:FindFirstChild("BaseHouse")
		local frame = model and model:GetAttribute(if site == "Company" then "PlotFrame" else "HouseFrame")
		if model and model:IsA("Model") and typeof(frame) == "CFrame" then return model, frame end
	end
	return nil, nil
end

local function siteProblem(player: Player, site: string, model: Model?, frame: CFrame?): string?
	if not model or not model:IsDescendantOf(workspace) or not frame then
		return if site == "Company" then "Your company plot is not ready." else "Your base house is not ready."
	end
	local actual = modelOf(player, site)
	if actual ~= model then return "You can only build on your own property." end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart")
		or (root.Position - frame.Position).Magnitude > (if site == "Company" then 150 else 110) then
		return "Return to your property to build."
	end
	return nil
end

local function history(player: Player, site: string, current)
	histories[player] = histories[player] or {}
	local record = histories[player][site]
	if not record or not same(record.Expected, current) then
		record = { Undo = {}, Redo = {}, Expected = clone(current) }
		histories[player][site] = record
	end
	return record
end

local function syncModel(plot: Model, site: string)
	if not plot:IsDescendantOf(workspace) then applied[plot] = nil; return end
	local userId = plot:GetAttribute("OwnerUserId")
	local player = if type(userId) == "number" and userId ~= 0 then Players:GetPlayerByUserId(userId) else nil
	local model = if site == "Company" then plot else plot:FindFirstChild("BaseHouse")
	local frame = model and model:GetAttribute(if site == "Company" then "PlotFrame" else "HouseFrame")
	if not model or not model:IsA("Model") or typeof(frame) ~= "CFrame" then return end
	local data = siteData(if player then BoatService.getProfile(player) else nil, site)
	local previous = applied[plot]
	if previous and previous.Model == model and previous.Owner == userId and previous.Frame == frame and same(previous.Data, data) then return end
	Renderer.sync(model, frame, site, data)
	applied[plot] = { Model = model, Frame = frame, Owner = userId, Data = clone(data) }
end

local function syncPlayer(player: Player)
	for _, tag in { "PlayerBase", "CompanyIsland" } do
		for _, plot in CollectionService:GetTagged(tag) do
			if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
				syncModel(plot, if tag == "CompanyIsland" then "Company" else "Home")
			end
		end
	end
end

local function state(player: Player, site: string)
	local profile = BoatService.getProfile(player)
	if not profile then return nil end
	local current = siteData(profile, site)
	local record = history(player, site, current)
	local model, frame = modelOf(player, site)
	return {
		Cash = profile.Cash,
		Pieces = current.Pieces,
		Overrides = current.Overrides,
		Builtins = if model and frame then Renderer.capture(model, frame, site) else {},
		CanUndo = #record.Undo > 0,
		CanRedo = #record.Redo > 0,
		Revision = player:GetAttribute("AnglerRevision") or 0,
	}
end

local function find(pieces, id)
	for index, entry in pieces do if entry.Id == id then return entry, index end end
	return nil, nil
end

local function overlaps(a, b): boolean
	return a[1] < b[3] - 0.02 and a[3] > b[1] + 0.02 and a[2] < b[4] - 0.02 and a[4] > b[2] + 0.02
end

local function equipmentProblem(profile, site, entry): string?
	if (entry.Kind ~= "Wall" and entry.Kind ~= "Stairs") or entry.Level ~= 0 then return nil end
	local wall = { math.min(entry.X1, entry.X2) - 0.2, math.min(entry.Z1, entry.Z2) - 0.2,
		math.max(entry.X1, entry.X2) + 0.2, math.max(entry.Z1, entry.Z2) + 0.2 }
	local placed = if site == "Company" then profile.Angler.CompanyFurniture else profile.Angler.Furniture
	for _, item in placed do
		local body = Furniture.body(item.ItemId, item.X, item.Z, item.R)
		if body and overlaps(wall, body) then return "Move the furniture out of the construction area first." end
	end
	-- These narrow passages lead to permanent gameplay fixtures. The furniture
	-- system also reserves them, and walls must keep the same routes usable.
	local passages = if site == "Company" then { { -4.5, -31.5, 4.5, -27 } } else {
		{ -4, 65.6, 4, 78.4 }, -- customer entrance
		{ 15.6, 69.5, 21.7, 78.5 }, -- built-in freezer
		{ -21, 65.6, -11.5, 74.9 }, -- register
		{ -4, 11.25, 1.95, 15.4 }, -- kitchen entrance
		{ 2.55, 11.25, 8, 15.4 }, -- storage entrance
		{ -1, -11.25, 6.5, -2.25 }, -- storage passage
		{ -5.8, -15.4, 1.95, -11 }, -- rear door
		{ -22.6, -14.6, -18, -1 }, -- prep benches
		{ -24.4, -30.5, -19.5, -23.5 }, -- dining entrance
	}
	for _, passage in passages do
		if overlaps(wall, passage) then return "Keep entrances and access to your working equipment clear." end
	end
	return nil
end

function Service.furnitureProblem(player: Player, entry, site: string?, currentProfile): string?
	local profile = currentProfile or BoatService.getProfile(player)
	if not profile then return "Your progress is still loading." end
	local body = Furniture.body(entry.ItemId, entry.X, entry.Z, entry.R)
	if not body then return nil end
	for _, wall in siteData(profile, site or "Home").Pieces do
		if (wall.Kind ~= "Wall" and wall.Kind ~= "Stairs") or wall.Level ~= 0 then continue end
		local area = { math.min(wall.X1, wall.X2) - 0.2, math.min(wall.Z1, wall.Z2) - 0.2,
			math.max(wall.X1, wall.X2) + 0.2, math.max(wall.Z1, wall.Z2) + 0.2 }
		if overlaps(body, area) then return "A custom wall or staircase blocks that furniture position." end
	end
	return nil
end

local function availableBuiltins(builtins, data)
	local result = {}
	for id, entry in builtins do
		if not (data.Overrides[id] and data.Overrides[id].Removed) then result[id] = entry end
	end
	return result
end

local function validate(profile, site, data, builtins): string?
	if #data.Pieces > Building.MAX_PIECES then return "This plot has reached its building limit." end
	local count = 0
	for _ in data.Overrides do count += 1 end
	if count > Building.MAX_OVERRIDES then return "This plot has reached its surface editing limit." end
	local hosts = availableBuiltins(builtins, data)
	local info = profile.SaveInfo
	local expanded = info ~= nil and (info.PlotExpanded == true or info.Multiplayer == true)
	for _, entry in data.Pieces do
		local problem = Building.check(data.Pieces, entry, site, hosts, entry.Id, expanded)
		if problem then return problem end
		if entry.Kind == "Wall" then
			for _, original in hosts do
				if original.Kind ~= "Wall" or original.Level ~= entry.Level then continue end
				local xLine = math.abs(entry.X2 - entry.X1) < 0.01 and math.abs(original.X2 - original.X1) < 0.01
					and math.abs(entry.X1 - original.X1) < 0.05
				local zLine = math.abs(entry.Z2 - entry.Z1) < 0.01 and math.abs(original.Z2 - original.Z1) < 0.01
					and math.abs(entry.Z1 - original.Z1) < 0.05
				if (xLine and math.min(entry.Z2, original.Z2) > math.max(entry.Z1, original.Z1) + 0.05)
					or (zLine and math.min(entry.X2, original.X2) > math.max(entry.X1, original.X1) + 0.05) then
					return "An existing wall covers this line. Paint it or remove it first."
				end
			end
		elseif entry.HostId then
			local host = hosts[entry.HostId]
			local _, bottom = Building.opening(entry)
			if host and host.BaseY and host.BaseY > 0.3 + (host.Level or 0) * Building.LEVEL_HEIGHT + bottom then
				return "Place this opening on a complete wall section."
			end
		end
		problem = equipmentProblem(profile, site, entry)
		if problem then return problem end
	end
	return nil
end

local function validId(id): boolean
	return Building.id(id)
end

local function builtinTargets(builtins, id)
	local selected = builtins[id]
	local group = if selected and selected.Kind == "Roof" then id:match("^(b:.+)/[^/]+$") else nil
	if not group then return { id } end
	local result = {}
	for otherId, entry in builtins do
		if entry.Kind == "Roof" and otherId:match("^(b:.+)/[^/]+$") == group then table.insert(result, otherId) end
	end
	return result
end

local function paint(data, payload, builtins, single): string?
	if type(payload) ~= "table" or not validId(payload.Id) then return "Select a building piece first." end
	local custom, index = find(data.Pieces, payload.Id)
	local target = custom or builtins[payload.Id]
	if not target or (data.Overrides[payload.Id] and data.Overrides[payload.Id].Removed) then return "That building piece is no longer there." end
	local previous = data.Overrides[payload.Id] or {}
	local sample = clone(custom or {Kind="Wall",X1=0,Z1=0,X2=Building.GRID,Z2=0,Level=0})
	sample.Color = payload.Color or previous.Color or target.Color
	sample.Material = payload.Material or previous.Material or target.Material
	if payload.Style ~= nil and payload.Style ~= sample.Style then return "Choose a shape from its catalogue to replace this piece." end
	local normalized, problem = Building.normalize(sample)
	if not normalized then return problem or "Choose a valid material and color." end
	if custom then
		normalized.Id = custom.Id
		data.Pieces[index] = normalized
	else
		-- `single` paints just this surface instead of its whole roof group.
		for _, id in (if single then { payload.Id } else builtinTargets(builtins, payload.Id)) do
			local override = data.Overrides[id] or {}
			override.Material, override.Color = normalized.Material, clone(normalized.Color)
			data.Overrides[id] = override
		end
	end
	return nil
end

-- Pure transformation used once for rejection before a save and again against
-- the newest profile inside the atomic wallet update.
local function change(profile, site, action, payload, builtins, record)
	local before = siteData(profile, site)
	local data = clone(before)
	local cost = 0
	if action == "Undo" or action == "Redo" then
		local list = if action == "Undo" then record.Undo else record.Redo
		local item = list[#list]
		if not item or not same(before, record.Expected) then return nil, "There is no building change to " .. string.lower(action) .. "." end
		data = clone(if action == "Undo" then item.Before else item.After)
		cost = if action == "Undo" then -item.Cost else item.Cost
	elseif action == "Place" then
		if type(payload.Entries) ~= "table" or #payload.Entries == 0 or #payload.Entries > BATCH_LIMIT then
			return nil, "Draw up to 64 building pieces at a time."
		end
		if data.NextId + #payload.Entries >= 1000000000 then return nil, "This plot has reached its lifetime building limit." end
		local count = 0
		for index, raw in payload.Entries do
			count += 1
			if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #payload.Entries or count > BATCH_LIMIT then
				return nil, "Invalid building selection."
			end
			local entry, problem = Building.normalize(raw)
			if not entry then return nil, problem or "Invalid building piece." end
			if entry.Kind == "Stairs" then return nil, "Stairs are no longer in the build catalogue." end
			entry.Id = "p" .. tostring(data.NextId)
			data.NextId += 1
			table.insert(data.Pieces, entry)
			cost += Building.price(entry)
		end
	elseif action == "PaintAllWalls" then
		-- Resolve targets from the current property inside the transaction so this
		-- stays one undoable edit even when there are more than 64 wall sections.
		local ids = {}
		for _, entry in data.Pieces do
			if entry.Kind == "Wall" then table.insert(ids, entry.Id) end
		end
		for id, entry in availableBuiltins(builtins, data) do
			if entry.Kind == "Wall" then table.insert(ids, id) end
		end
		-- The plaster triangles under a pitched roof ("Gable", "ShopGable") are
		-- captured as Roof parts but read as wall. Paint each one on its own so
		-- the roof group they share keeps its tiles.
		local gables = {}
		for id, entry in availableBuiltins(builtins, data) do
			local name = id:match("([^/]+)$") or ""
			if entry.Kind == "Roof" and name:match("^%w*Gable_%d+$") then table.insert(gables, id) end
		end
		if #ids == 0 then return nil, "There are no walls to paint on this property." end
		for _, id in ids do
			local problem = paint(data, { Id = id, Material = payload.Material, Color = payload.Color }, builtins)
			if problem then return nil, problem end
		end
		for _, id in gables do
			local problem = paint(data, { Id = id, Material = payload.Material, Color = payload.Color }, builtins, true)
			if problem then return nil, problem end
		end
	elseif action == "Paint" or action == "PaintBatch" then
		if action == "Paint" then
			local problem = paint(data, payload, builtins)
			if problem then return nil, problem end
		else
			if type(payload.Entries) ~= "table" or #payload.Entries < 1 or #payload.Entries > BATCH_LIMIT then return nil, "Paint up to 64 surfaces at a time." end
			local count = 0
			for index, entry in payload.Entries do
				count += 1
				if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #payload.Entries or count > BATCH_LIMIT then return nil, "Invalid painting selection." end
				local problem = paint(data, entry, builtins)
				if problem then return nil, problem end
			end
		end
	elseif action == "Remove" then
		if not validId(payload.Id) then return nil, "Select a building piece first." end
		local custom, index = find(data.Pieces, payload.Id)
		if custom then
			table.remove(data.Pieces, index)
		elseif builtins[payload.Id] and not (data.Overrides[payload.Id] and data.Overrides[payload.Id].Removed) then
			for _, id in builtinTargets(builtins, payload.Id) do
				local override = data.Overrides[id] or {}
				override.Removed = true
				data.Overrides[id] = override
			end
		else
			return nil, "That building piece is no longer there."
		end
		-- Openings belong to their wall and cannot survive without their host.
		for at = #data.Pieces, 1, -1 do
			if data.Pieces[at].HostId == payload.Id then table.remove(data.Pieces, at) end
		end
	elseif action == "Move" then
		if not validId(payload.Id) then return nil, "Select a building piece first." end
		local custom, index = find(data.Pieces, payload.Id)
		local entry, problem = Building.normalize(payload.Entry)
		if not entry then return nil, problem or "Invalid building position." end
		if custom then
			if entry.Kind ~= custom.Kind then return nil, "Choose the same building category when moving a piece." end
			entry.Id = custom.Id
			data.Pieces[index] = entry
			cost = math.max(0, Building.price(entry) - Building.price(custom))
		else
			-- Original full-height walls become your own piece: the original is hidden
			-- and an equivalent custom wall takes its new position, as one undoable edit.
			local original = availableBuiltins(builtins, data)[payload.Id]
			if not original then return nil, "That building piece is no longer there." end
			if not Building.movableOriginal(original) then
				return nil, "This original part can be painted or removed. Full-height walls can also be moved."
			end
			if entry.Kind ~= original.Kind then return nil, "Choose the same building category when moving a piece." end
			if data.NextId + 1 >= 1000000000 then return nil, "This plot has reached its lifetime building limit." end
			entry.Id = "p" .. tostring(data.NextId)
			data.NextId += 1
			local override = data.Overrides[payload.Id] or {}
			override.Removed = true
			data.Overrides[payload.Id] = override
			-- Doors and windows you added to the original wall move with it.
			for _, piece in data.Pieces do
				if piece.HostId == payload.Id then piece.HostId = entry.Id end
			end
			table.insert(data.Pieces, entry)
			cost = math.max(0, Building.price(entry) - Building.price(original))
		end
	else
		return nil, "That building tool is unavailable."
	end
	if same(before, data) then
		if action == "Paint" or action == "PaintBatch" or action == "PaintAllWalls" then return {Before=clone(before),After=clone(data),Cost=0,Noop=true},nil end
		return nil, "That surface already has this finish."
	end
	local problem = validate(profile, site, data, builtins)
	if problem then return nil, problem end
	if profile.Cash < cost then return nil, string.format("You need $%d for this build.", cost) end
	profile.Angler.Building = profile.Angler.Building or Building.decode(nil)
	profile.Angler.Building[site] = data
	profile.Cash -= cost
	return { Before = clone(before), After = clone(data), Cost = cost }, nil
end

local function edit(player: Player, action: string, payload, site: string): (boolean, string)
	if busy[player] then return false, "Please wait for your previous building change to save." end
	local model, frame = modelOf(player, site)
	local problem = siteProblem(player, site, model, frame)
	if problem then return false, problem end
	local profile = BoatService.getProfile(player)
	if not profile then return false, "Your progress is still loading." end
	local builtins = Renderer.capture(model, frame, site)
	local record = history(player, site, siteData(profile, site))
	local proposed, reason = change(profile, site, action, payload, builtins, record)
	if reason then return false, reason end
	if proposed.Noop then return true, "Saved." end
	busy[player] = true
	local committed
	local ok, message = BoatService.updateProgress(player, function(current)
		local failure = siteProblem(player, site, model, frame)
		assert(not failure, failure)
		local changed, rejected = change(current, site, action, payload, builtins, record)
		assert(changed, rejected)
		committed = changed
	end)
	busy[player] = nil
	if not ok then return false, message end
	if committed.Noop then syncPlayer(player); return true, "Saved." end
	if action == "Undo" then
		local item = table.remove(record.Undo)
		table.insert(record.Redo, item)
	elseif action == "Redo" then
		local item = table.remove(record.Redo)
		table.insert(record.Undo, item)
	else
		table.insert(record.Undo, committed)
		if #record.Undo > HISTORY_LIMIT then table.remove(record.Undo, 1) end
		table.clear(record.Redo)
	end
	record.Expected = clone(committed.After)
	-- publish() fires AnglerRevision before updateProgress returns. Restore the
	-- completed history after that listener has observed the new profile.
	histories[player][site] = record
	syncPlayer(player)
	return true, if action == "Place" then string.format("Built for $%d.", committed.Cost) else "Saved."
end

function Service.start()
	if started then return end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "Building"
	local request = Instance.new("RemoteFunction")
	request.Name, request.Parent = "Request", remotes
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent = "Update", remotes
	remotes.Parent = ReplicatedStorage
	request.OnServerInvoke = function(player, action, payload, requestedSite)
		local site = requestedSite or "Home"
		if site ~= "Home" and site ~= "Company" then return { Ok = false, Message = "Unknown building plot." } end
		if action == "Get" then return { Ok = true, State = state(player, site) } end
		if type(action) ~= "string" or type(payload or {}) ~= "table" then return { Ok = false, Message = "Invalid building request." } end
		if action == "PaintBatch" then
			local now = os.clock()
			local bucket = paintRequests[player] or {Tokens=4,At=now}
			bucket.Tokens = math.min(4, bucket.Tokens + math.max(0, now - bucket.At) * 10)
			bucket.At = now
			paintRequests[player] = bucket
			if bucket.Tokens < 1 then return {Ok=false,RetryAfter=0.1,Message="Painting is saving. Try again in a moment.",State=state(player,site)} end
			bucket.Tokens -= 1
		else
			if os.clock() - (requests[player] or -math.huge) < 0.3 then
				return { Ok = false, Message = "Please wait a moment before using another tool.", State = state(player, site) }
			end
			requests[player] = os.clock()
		end
		local ok, message = edit(player, action, payload or {}, site)
		return { Ok = ok, Message = message, State = state(player, site) }
	end
	local function bindPlayer(player: Player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			syncPlayer(player)
			-- Do not expose a temporarily stale undo list during our own commit.
			if not busy[player] then
				for _, site in { "Home", "Company" } do update:FireClient(player, "State", state(player, site), site) end
			end
		end)
		syncPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in Players:GetPlayers() do bindPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		requests[player], busy[player], histories[player], paintRequests[player] = nil, nil, nil, nil
	end)
	local function watch(plot: Instance, site: string)
		if not plot:IsA("Model") or watched[plot] then return end
		watched[plot] = true
		local function queue()
			if queued[plot] then return end
			queued[plot] = true
			task.defer(function()
				queued[plot] = nil
				if plot.Parent then syncModel(plot, site) end
			end)
		end
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(queue)
		plot:GetAttributeChangedSignal(if site == "Company" then "PlotFrame" else "HouseFrame"):Connect(queue)
		plot.DescendantAdded:Connect(function(child)
			if child.Name == "BaseHouse" or child.Name == "Dressing" then applied[plot] = nil; queue() end
		end)
		plot.Destroying:Connect(function() watched[plot], queued[plot], applied[plot] = nil, nil, nil end)
		queue()
	end
	for _, tag in { "PlayerBase", "CompanyIsland" } do
		local site = if tag == "CompanyIsland" then "Company" else "Home"
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(plot) watch(plot, site) end)
		for _, plot in CollectionService:GetTagged(tag) do watch(plot, site) end
	end
end

return Service
