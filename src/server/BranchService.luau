-- Buying a company branch from the office PC's BRANCHES app (client BranchApp).
-- A fishing company can open the café branch and a café company the fishing
-- branch (Shared.Branches); the price comes out of the shared company wallet.
-- Like the stock exchange, orders are only accepted while the player sits at
-- one of their own office PCs (OfficeComputerService.atDesk).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatService = require(script.Parent.BoatService)
local Branches = require(ReplicatedStorage.Shared.Branches)
local OfficeComputerService = require(script.Parent.OfficeComputerService)

local Service = {}
local started = false

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return { Ok = false, Message = "Your company is still loading." }
	end
	local owned = Branches.normalize(profile.Branches)
	local list = {}
	for _, id in Branches.ORDER do
		local info = Branches.Info[id]
		table.insert(list, {
			Id = id,
			Title = info.Title,
			Blurb = info.Blurb,
			Price = info.Price,
			Owned = owned[id] == true,
		})
	end
	return { Ok = true, Branches = list, Cash = profile.Cash }
end

local function buy(player: Player, id: any)
	if not Branches.valid(id) then
		return { Ok = false, Message = "Unknown branch." }
	end
	if not OfficeComputerService.atDesk(player) then
		return { Ok = false, Message = "Sit at your office PC to buy a branch." }
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return { Ok = false, Message = "Your company is still loading." }
	end
	local info = Branches.Info[id]
	if Branches.has(profile, id) then
		return { Ok = false, Message = "Your company already has the " .. string.lower(info.Title) .. "." }
	end
	if profile.Cash < info.Price then
		return { Ok = false, Message = string.format("The %s costs $%d. Your company has $%d.", string.lower(info.Title), info.Price, profile.Cash) }
	end
	local ok, message = BoatService.updateProgress(player, function(current)
		-- UpdateAsync may retry: the purchase rule runs against the stored profile.
		Branches.buy(current, id)
	end)
	if not ok then
		return { Ok = false, Message = message }
	end
	local result = state(player)
	result.Message = if id == "Cafe"
		then "Café branch opened! Your café is in the city's café quarter, by the metro station."
		else "Fishing branch opened! Your dock is ready at Gullhaven harbour."
	return result
end

function Service.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "Branches"
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Request"
	remote.Parent = folder
	folder.Parent = ReplicatedStorage

	local lastRequest: { [Player]: number } = {}
	remote.OnServerInvoke = function(player, action, value)
		if os.clock() - (lastRequest[player] or -math.huge) < 0.4 then
			return { Ok = false, Message = "One moment..." }
		end
		lastRequest[player] = os.clock()
		if action == "State" then
			return state(player)
		elseif action == "Buy" then
			return buy(player, value)
		end
		return { Ok = false, Message = "Unknown request." }
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Service
