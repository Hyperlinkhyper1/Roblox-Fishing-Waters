-- Micro Harbour, the computer superstore in the city (Map/TechStore, Shared.TechCatalog). Builds
-- the store and sells PC components, monitors and software licenses at their physical rack
-- displays. Parts go into the company's parts bin and are fitted at a base's workbench; a
-- complete PC is handed over to carry home (PcWorkshopService). Purchases belong to the company
-- save (`Tech` on the profile), so every member's office PC shows them.
--
-- Mirrors the installed parts and licenses onto each player as attributes (Tech<Slot>,
-- License<Id>) for the office PC client, and dresses every office desk's PC model in its
-- company's parts (Map/OfficeDesk.dress).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatService = require(script.Parent.BoatService)
local OfficeDesk = require(script.Parent.Map.OfficeDesk)
local PcWorkshop = require(script.Parent.PcWorkshopService)
local PcModel = require(ReplicatedStorage.Shared.PcModel)
local TechStore = require(script.Parent.Map.TechStore)
local TechCatalog = require(ReplicatedStorage.Shared.TechCatalog)
local Layout = require(ReplicatedStorage.Shared.TechStoreLayout)

local Service = {}
local started = false
local requests: { [Player]: number } = {}

local BASE_TAG = "PlayerBase"
local CAFE_TAG = "CafePlot"
-- How often desks are checked against their owners' parts (ownership, rebuilds and streaming
-- all settle on their own; there are only ~30 desks).
local DRESS_SECONDS = 2

local function atProduct(player: Player, kind: string, id: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	for _, store in CollectionService:GetTagged(TechCatalog.STORE_TAG) do
		if store:IsDescendantOf(workspace) then
			local frame = store:GetAttribute("StoreFrame")
			if typeof(frame) == "CFrame" and Layout.nearProduct(frame, root.Position, kind, id) then
				return true
			end
		end
	end
	return false
end

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return nil
	end
	local tech = TechCatalog.decode(profile.Tech)
	return { Cash = profile.Cash, Owned = tech.Owned, Equipped = tech.Equipped, Licenses = tech.Licenses }
end

local function mirror(player: Player)
	local profile = BoatService.getProfile(player)
	local tech = TechCatalog.decode(profile and profile.Tech)
	for _, slot in TechCatalog.Slots do
		player:SetAttribute(TechCatalog.slotAttribute(slot), tech.Equipped[slot])
	end
	for id in TechCatalog.Licenses do
		player:SetAttribute(TechCatalog.licenseAttribute(id), tech.Licenses[id] == true)
	end
end

-- The look of the PC that belongs to `holder` (a harbour base or a café plot), from any of its
-- company's players in this server. Unowned desks go back to the starter PC.
local function lookFor(holder: Instance)
	local player: Player? = nil
	if CollectionService:HasTag(holder, CAFE_TAG) then
		local companyId = holder:GetAttribute("CompanyId")
		if type(companyId) == "string" and companyId ~= "" then
			for _, candidate in Players:GetPlayers() do
				if candidate:GetAttribute("CompanyId") == companyId then
					player = candidate
					break
				end
			end
		end
	else
		local owner = holder:GetAttribute("OwnerUserId")
		player = if type(owner) == "number" and owner ~= 0 then Players:GetPlayerByUserId(owner) else nil
	end
	local equipped = {}
	for _, slot in TechCatalog.Slots do
		equipped[slot] = player and player:GetAttribute(TechCatalog.slotAttribute(slot))
	end
	local look = TechCatalog.deskLook(equipped)
	look.Away = PcWorkshop.isAway(holder)
	return look
end

local function dressAll()
	for _, tag in { BASE_TAG, CAFE_TAG } do
		for _, holder in CollectionService:GetTagged(tag) do
			if holder:IsDescendantOf(workspace) then
				local desk = holder:FindFirstChild("OfficeDesk", true)
				if desk and desk:IsA("Model") then
					local ok, problem = pcall(OfficeDesk.dress, desk, lookFor(holder), PcModel)
					if not ok then
						warn("[TechStore] Could not dress an office PC: " .. tostring(problem))
					end
				end
			end
		end
	end
end

local function purchase(player: Player, kind: string, id: any)
	local profile = BoatService.getProfile(player)
	if not profile then
		return { Ok = false, Message = "Your company is still loading." }
	end
	if type(id) ~= "string" or not atProduct(player, kind, id) then
		return { Ok = false, Message = "Hold E at this product's price tag inside " .. TechCatalog.STORE_NAME .. ".", State = state(player) }
	end
	if kind == "Prebuilt" then
		local free, why = PcWorkshop.canReceive(player)
		if not free then
			return { Ok = false, Message = why, State = state(player) }
		end
	end
	local failure = TechCatalog.problem(TechCatalog.decode(profile.Tech), profile.Cash, kind, id)
	if failure then
		return { Ok = false, Message = failure, State = state(player) }
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		local tech = TechCatalog.decode(current.Tech)
		local reason = TechCatalog.problem(tech, current.Cash, kind, id)
		assert(not reason, reason)
		local price = TechCatalog.buy(tech, kind, id)
		current.Cash -= price
		current.Angler.Stats.CoinsSpent += price
		current.Tech = TechCatalog.encode(tech)
	end)
	if ok then
		mirror(player)
	end
	local name = TechCatalog.product(kind, id).Name
	if ok and kind == "Prebuilt" and not PcWorkshop.giveFromShop(player, TechCatalog.Prebuilts[id].Parts, name) then
		return { Ok = true, Message = "Paid for " .. name .. ". Hold E again to pick it up (it's free now).", State = state(player) }
	end
	return {
		Ok = ok,
		Message = if not ok
			then message
			elseif kind == "License" then name .. " activated! Open the app on your office PC."
			elseif kind == "Prebuilt" then name .. " is in your arms! Carry it to your desk, or to your workbench to tinker."
			else name .. " is in your parts bin. Fit it at the workbench in your base.",
		State = state(player),
	}
end

function Service.start(root: Instance)
	if started then
		return
	end
	started = true
	TechStore.ensure(root)
	PcWorkshop.start({
		changed = function(player)
			if player then
				mirror(player)
			end
			dressAll()
		end,
	})

	local remote = Instance.new("RemoteFunction")
	remote.Name = "TechStore"
	remote.OnServerInvoke = function(player, action, kind, id)
		if os.clock() - (requests[player] or -math.huge) < 0.25 then
			return { Ok = false, Message = "Please wait a moment.", State = state(player) }
		end
		requests[player] = os.clock()
		if action == "Get" then
			local current = state(player)
			return { Ok = current ~= nil, Message = if current then nil else "Your company is still loading.", State = current }
		elseif action == "Buy" and (kind == "Item" or kind == "License" or kind == "Prebuilt") then
			return purchase(player, kind, id)
		elseif action == "Equip" then
			return { Ok = false, Message = "Fit parts at the workbench in your base.", State = state(player) }
		end
		return { Ok = false, Message = "That action is unavailable." }
	end
	remote.Parent = ReplicatedStorage

	local function bind(player: Player)
		-- Every committed save (this member's or a company mate's) bumps AnglerRevision.
		player:GetAttributeChangedSignal("AnglerRevision"):Connect(function()
			mirror(player)
		end)
		mirror(player)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		requests[player] = nil
	end)

	task.spawn(function()
		while true do
			dressAll()
			task.wait(DRESS_SECONDS)
		end
	end)
end

return Service
