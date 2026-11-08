-- Ownership is checked by the server, cached per session and refreshed after purchases.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Passes = require(game:GetService("ReplicatedStorage").Shared.Gamepasses)
local Service = {}
local cache = {}
-- Grants from the luma admin dashboard, keyed by pass then user id. They are
-- benefit overrides like grantForSession, and DashboardService replaces the
-- whole set after every heartbeat.
local dashboardGrants = {}
local started = false
local COMMAND_USER_ID = 2541746813 -- hyperlinkhyper

local function attribute(key)
	return "Owns" .. key
end

local function entries(player)
	cache[player] = cache[player] or {}
	return cache[player]
end

local function owns(player, key)
	if dashboardGrants[key] and dashboardGrants[key][player.UserId] then
		player:SetAttribute(attribute(key), true)
		return true
	end
	local entry = entries(player)[key]
	if entry and (entry.owned or os.clock() < entry.retryAt) then
		return entry.owned
	end
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Passes[key].Id)
	end)
	if player.Parent ~= Players then return false end
	local current = entries(player)[key]
	if current and current.owned then return true end
	local verified = ok and owned == true
	entries(player)[key] = { owned = verified, retryAt = os.clock() + (if ok then 60 else 10) }
	local granted = (dashboardGrants[key] and dashboardGrants[key][player.UserId]) == true
	player:SetAttribute(attribute(key), verified or granted)
	return verified or granted
end

function Service.ownsAutoStore(player: Player): boolean
	return owns(player, "AutoStore")
end

function Service.ownsDoubleXP(player: Player): boolean
	return owns(player, "DoubleXP")
end

-- Infinite fish storage. BackpackCatalog.layoutFor reads the replicated
-- OwnsBlackHoleBackpack attribute this sets, so every service agrees.
function Service.ownsBlackHoleBackpack(player: Player): boolean
	return owns(player, "BlackHoleBackpack")
end

-- Unlocks buying and placing boat furniture at the drydock refit dock.
function Service.ownsBoatCustomization(player: Player): boolean
	return owns(player, "BoatCustomization")
end

function Service.grantForSession(player: Player, key: string): (boolean, string)
	if player.UserId ~= COMMAND_USER_ID or player.Parent ~= Players then
		return false, "This command is unavailable."
	end
	if not Passes[key] then
		return false, "Unknown gamepass. Use /gamepass list for available names."
	end
	entries(player)[key] = { owned = true }
	player:SetAttribute(attribute(key), true)
	return true, Passes[key].Name .. " enabled for this server session."
end

function Service.setDashboardGrants(grants: { [string]: { number } })
	local previous = dashboardGrants
	dashboardGrants = {}
	for key, userIds in grants do
		if Passes[key] then
			local set = {}
			for _, userId in userIds do set[userId] = true end
			dashboardGrants[key] = set
		end
	end
	for _, player in Players:GetPlayers() do
		for key in Passes do
			local was = previous[key] and previous[key][player.UserId]
			local now = dashboardGrants[key] and dashboardGrants[key][player.UserId]
			if now then
				player:SetAttribute(attribute(key), true)
			elseif was then
				local entry = cache[player] and cache[player][key]
				player:SetAttribute(attribute(key), entry ~= nil and entry.owned == true)
				if not entry then task.spawn(owns, player, key) end
			end
		end
	end
end

function Service.start()
	if started then return end
	started = true
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and player.Parent == Players then
			for key, pass in Passes do
				if passId == pass.Id then
					entries(player)[key] = { owned = true }
					player:SetAttribute(attribute(key), true)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) cache[player] = nil end)
	local function bind(player)
		for key in Passes do task.spawn(owns, player, key) end
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do bind(player) end
end

return Service
