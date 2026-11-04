-- Saved property entitlement, exclusive server plots, and the island's look: plain
-- wild land while free, the owner's village and furnished plot while assigned.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Access = require(script.Parent.CompanyIslandAccess)
local BoatService = require(script.Parent.BoatService)
local FurnitureService = require(script.Parent.FurnitureService)
local MapIslands = require(script.Parent.Map.CompanyIslands)
local Layout = require(ReplicatedStorage.Shared.CompanyIslands)

local Service = {}
local started = false
local reserved, busy, requests = {}, {}, {}
local update: RemoteEvent

local function properties()
	local result = CollectionService:GetTagged(Layout.TAG)
	table.sort(result, function(a, b)
		return a:GetAttribute("IslandId") < b:GetAttribute("IslandId")
	end)
	return result
end

local function nearBoard(player, island): boolean
	local board = island:FindFirstChild("PropertyBoard")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return island:IsDescendantOf(workspace) and board ~= nil and root ~= nil
		and humanoid ~= nil and humanoid.Health > 0 and (root.Position - board.Position).Magnitude <= 14
end

local function refresh(island: Model, player: Player?)
	MapIslands.dress(island, player ~= nil)
	FurnitureService.syncCompany(island)
	local board = island:FindFirstChild("PropertyBoard")
	for _, label in if board then board:GetDescendants() else {} do
		if label:IsA("TextLabel") then
			label.Text = if player then player.DisplayName .. "'s Company" else Layout.Names[island:GetAttribute("IslandId")] .. " / $50,000"
		end
	end
	for _, prompt in island:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			if CollectionService:HasTag(prompt, "ShopOwnerPrompt") then
				prompt:SetAttribute("OwnerUserId", if player then player.UserId else 0)
			elseif prompt.Name == "BuyCompanyIslandPrompt" then
				prompt.Enabled = player == nil
			end
		end
	end
end

local function assign(player: Player)
	if player.Parent ~= Players then
		return
	end
	local profile = BoatService.getProfile(player)
	if not profile or not profile.Angler.CompanyIsland then
		return
	end
	local existing = Access.get(player)
	if existing then
		refresh(existing, player)
		return
	end
	local free
	for _, island in properties() do
		if island:GetAttribute("OwnerUserId") == 0 and (not reserved[island] or reserved[island] == player) then
			free = free or island
			if island:GetAttribute("IslandId") == profile.Angler.CompanyIsland then
				free = island
				break
			end
		end
	end
	if free then
		free:SetAttribute("OwnerUserId", player.UserId)
		player:SetAttribute("CompanyIslandId", free:GetAttribute("IslandId"))
		player:SetAttribute("CompanyIslandWaiting", false)
		refresh(free, player)
		update:FireClient(player, "Notice", "Your company island is " .. Layout.Names[free:GetAttribute("IslandId")] .. ". Find it on the map around Gullhaven.")
	else
		player:SetAttribute("CompanyIslandId", nil)
		if not player:GetAttribute("CompanyIslandWaiting") then
			player:SetAttribute("CompanyIslandWaiting", true)
			update:FireClient(player, "Notice", "All company islands are occupied. Your ownership is saved; a plot will be assigned when one becomes free.")
		end
	end
end

local function inspect(player, island)
	local profile = BoatService.getProfile(player)
	local problem = Layout.purchaseProblem(profile)
	if island:GetAttribute("OwnerUserId") ~= 0 or reserved[island] then
		problem = "This island is already occupied."
	end
	return { Id = island:GetAttribute("IslandId"), Name = Layout.Names[island:GetAttribute("IslandId")], Price = Layout.PRICE, Problem = problem }
end

local function purchase(player, island)
	local problem = inspect(player, island).Problem
	if problem then
		return { Ok = false, Message = problem }
	elseif busy[player] then
		return { Ok = false, Message = "Your island purchase is being saved." }
	end
	-- Reserve before the DataStore call yields, so two buyers cannot buy one plot.
	busy[player], reserved[island] = true, player
	local ok, message = BoatService.updateProgress(player, function(current)
		local saved, failure = Layout.purchase(current, island:GetAttribute("IslandId"))
		assert(saved, failure)
		current.Cash, current.Angler = saved.Cash, saved.Angler
	end)
	busy[player], reserved[island] = nil, nil
	if ok then
		assign(player)
		message ="Island purchased! Your storage racks, prep benches, kitchen storage and desk are in build mode: press B on your island's plot to place them."
	end
	return { Ok = ok, Message = message }
end

function Service.start()
	if started then return end
	started = true
	local remotes = Instance.new("Folder")
	remotes.Name = "CompanyIslands"
	local request = Instance.new("RemoteFunction")
	request.Name, request.Parent = "Request", remotes
	update = Instance.new("RemoteEvent")
	update.Name, update.Parent, remotes.Parent = "Update", remotes, ReplicatedStorage
	request.OnServerInvoke = function(player, action, id)
		if os.clock() - (requests[player] or -math.huge) < 0.4 then
			return { Ok = false, Message = "Please wait a moment." }
		end
		requests[player] = os.clock()
		if not Layout.validId(id) then return { Ok = false, Message = "Unknown island." } end
		for _, island in properties() do
			if island:GetAttribute("IslandId") == id and nearBoard(player, island) then
				if action == "Inspect" then return { Ok = true, Island = inspect(player, island) } end
				if action == "Buy" then return purchase(player, island) end
			end
		end
		return { Ok = false, Message = "Walk up to the island's purchase board." }
	end
	local function watchIsland(island)
		if not island:IsA("Model") then return end
		-- A Studio bake can contain session ownership; every server allocates afresh.
		island:SetAttribute("OwnerUserId", 0)
		refresh(island, nil)
	end
	for _, island in properties() do watchIsland(island) end
	CollectionService:GetInstanceAddedSignal(Layout.TAG):Connect(watchIsland)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "BuyCompanyIslandPrompt" then return end
		local island = prompt:FindFirstAncestorOfClass("Model")
		if island and CollectionService:HasTag(island, Layout.TAG) and nearBoard(player, island) then
			update:FireClient(player, "Inspect", inspect(player, island))
		end
	end)
	local function watch(player)
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function() assign(player) end)
		player:GetAttributeChangedSignal("BoatDataStatus"):Connect(function() assign(player) end)
		assign(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do watch(player) end
	Players.PlayerRemoving:Connect(function(player)
		local island = Access.get(player)
		if island then
			island:SetAttribute("OwnerUserId", 0)
			refresh(island, nil)
		end
		for property, buyer in reserved do
			if buyer == player then reserved[property] = nil end
		end
		requests[player], busy[player] = nil, nil
		task.defer(function()
			for _, waiting in Players:GetPlayers() do
				if waiting ~= player and not Access.get(waiting) then assign(waiting) end
			end
		end)
	end)
end

return Service
