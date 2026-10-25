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

-- Server-only override: grants the in-game benefit, not Marketplace ownership.
function Service.grantForSession(player: Player, key: string): (boolean, string)
	if player.UserId ~= COMMAND_USER_ID or player.Parent ~= Players then
		return false, "This command is unavailable."
	end
	if key ~= "AutoStore" then
		return false, "Unknown gamepass. Use /gamepass list for available names."
	end
	cache[player] = { owned = true }
	player:SetAttribute("OwnsAutoStore", true)
	return true, Passes.AutoStore.Name .. " enabled for this server session."
end

function Service.setDashboardGrants(grants: { [string]: { number } })
	local previous = dashboardGrants
	dashboardGrants = {}
	for key, userIds in grants do
		if Passes[key] then
			local set = {}
			for _, userId in userIds do
				set[userId] = true
			end
			dashboardGrants[key] = set
		end
	end
	for _, player in Players:GetPlayers() do
		local was = previous.AutoStore and previous.AutoStore[player.UserId]
		local now = dashboardGrants.AutoStore and dashboardGrants.AutoStore[player.UserId]
		if now then
			player:SetAttribute("OwnsAutoStore", true)
		elseif was then
			-- Revoked: fall back to whatever Marketplace or a purchase says.
			local entry = cache[player]
			player:SetAttribute("OwnsAutoStore", entry ~= nil and entry.owned == true)
			if not entry then
				task.spawn(Service.ownsAutoStore, player)
			end
		end
	end
end

function Service.ownsAutoStore(player: Player): boolean
	if dashboardGrants.AutoStore and dashboardGrants.AutoStore[player.UserId] then
		player:SetAttribute("OwnsAutoStore", true)
		return true
	end
	local entry = cache[player]
	if entry and (entry.owned or os.clock() < entry.retryAt) then
		return entry.owned
	end
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Passes.AutoStore.Id)
	end)
	if player.Parent ~= Players then
		return false
	end
	-- A purchase event may have granted ownership while the request was yielding.
	if cache[player] and cache[player].owned then
		return true
	end
	local verified = ok and owned == true
	cache[player] = { owned = verified, retryAt = os.clock() + (if ok then 60 else 10) }
	player:SetAttribute("OwnsAutoStore", verified)
	return verified
end

function Service.start()
	if started then
		return
	end
	started = true
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if passId == Passes.AutoStore.Id and purchased and player.Parent == Players then
			cache[player] = { owned = true }
			player:SetAttribute("OwnsAutoStore", true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
	local function bind(player)
		task.spawn(Service.ownsAutoStore, player)
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
end

return Service
