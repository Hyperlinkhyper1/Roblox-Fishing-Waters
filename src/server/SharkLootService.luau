local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoatService = require(script.Parent.BoatService)
local Data = require(script.Parent.AnglerData)
local SharkService = require(script.Parent.SharkService)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local Backpacks = require(ReplicatedStorage.Shared.BackpackCatalog)
local SharkDrops = require(ReplicatedStorage.Shared.SharkDrops)

local Service = {}
local started = false
local random = Random.new()

function Service.start()
	if started then
		return
	end
	started = true
	local remote = Instance.new("RemoteEvent")
	remote.Name = "SharkLoot"
	remote.Parent = ReplicatedStorage
	SharkService.setKillRewardCallback(function(player)
		local drops = SharkDrops.roll(random)
		local ids = {}
		for _, item in drops do
			table.insert(ids, item.FishId)
		end
		local caughtAt = os.time()
		local saved, overflow = false, false
		for attempt = 1, 4 do
			saved = BoatService.updateProgress(player, function(profile)
				local backpack = Backpacks.Items[profile.Angler.BackpackId] or Backpacks.Items.Starter
				profile.Angler, overflow = Data.recordSharkDrops(profile.Angler, ids, caughtAt, Catalog.Fish, backpack)
			end)
			if saved or player.Parent ~= Players then
				break
			end
			task.wait(attempt)
		end
		if player.Parent == Players then
			remote:FireClient(player, drops, saved, overflow)
		end
	end)
end

return Service
