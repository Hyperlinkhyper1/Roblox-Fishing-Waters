-- Production authorization and purchase functions are inserted by check-furniture-shop.mjs.
local originalVector = Vector3.new
function Vector3.new(...)
	local value = originalVector(...)
	value._type = "Vector3"
	return value
end
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local hall = Instance.new("Model")
hall.Name, hall.Parent = "FurnitureStoreInterior", workspace
hall:SetAttribute("InteriorFrame", CFrame.new(6700, 309, 160))
hall:SetAttribute("InteriorSize", Vector3.new(48, 18, 40))
local tagged = { hall }
function CollectionService:GetTagged(tag)
	assert(tag == "FurnitureShowroom")
	return tagged
end
local anchors = {}
for index, id in Furniture.Order do
	local anchor = Instance.new("Part")
	anchor.CFrame, anchor.Parent = CFrame.new(6700 + (index - 2) * 15, 301.7, 164.5), hall
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.Enabled, prompt.MaxActivationDistance = "BrowseFurniturePrompt", true, 7
	prompt:SetAttribute("ItemId", id)
	prompt.Parent = anchor
	anchors[id] = anchor
end
local counter = Instance.new("Part")
counter.CFrame, counter.Parent = CFrame.new(6683, 303.1, 153), hall
local browse = Instance.new("ProximityPrompt")
browse.Name, browse.Enabled, browse.MaxActivationDistance, browse.Parent = "BrowseFurniturePrompt", true, 7, counter
local player = Instance.new("Player")
local character = Instance.new("Model")
player.Character = character
local humanoid = Instance.new("Humanoid")
humanoid.Health, humanoid.Parent = 100, character
local root = Instance.new("Part")
root.Name, root.CFrame, root.Parent = "HumanoidRootPart", CFrame.new(), character
-- ROOT_SOURCE --
-- AUTH_SOURCE --
local function stand(anchor)
	root.CFrame = anchor.CFrame + Vector3.new(0, 1.5, -1)
end
for _, id in Furniture.Order do
	stand(anchors[id])
	check(atShop(player, id), "Matching display must authorize " .. id)
	for _, other in Furniture.Order do
		if other ~= id then check(not atShop(player, other), "Distant display must not authorize " .. other) end
	end
end
stand(counter)
for _, id in Furniture.Order do check(atShop(player, id), "Service counter must offer " .. id) end
root.CFrame = CFrame.new()
check(not atShop(player, "Freezer"), "Plaza/outside requests must be rejected")
stand(anchors.Freezer)
local bounds = hall:GetAttribute("InteriorSize")
hall:SetAttribute("InteriorSize", Vector3.new(1, 18, 40))
check(not atShop(player, "Freezer"), "Proximity outside the showroom bounds must not authorize")
hall:SetAttribute("InteriorSize", bounds)
hall.Parent = nil
check(not atShop(player, "Freezer"), "A detached showroom must not authorize")
hall.Parent = workspace
local displayPrompt = anchors.Freezer:FindFirstChild("BrowseFurniturePrompt")
displayPrompt.Enabled = false
check(not atShop(player, "Freezer"), "A disabled display must not authorize")
displayPrompt.Enabled = true
humanoid.Health = 0
check(not atShop(player, "Freezer"), "Dead players cannot buy furniture")
humanoid.Health = 100

local profile = { Cash = 2000, Angler = { FurnitureStock = {}, Stats = { CoinsSpent = 0 } } }
local busy, saves, synced = {}, 0, 0
local failSave = false
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[key] = copy(item) end
	return result
end
local BoatService = {
	-- BoatService.getProfile decodes a copy of the stored profile.
	getProfile = function() return if profile then copy(profile) else nil end,
	updateProgress = function(_, transform)
		saves += 1
		if failSave then return false, "Save failed" end
		local current = copy(profile)
		transform(current)
		profile = current
		return true, ""
	end,
}
local AnglerData = {
	buyFurniture = function(data, id)
		local result = copy(data)
		result.FurnitureStock[id] = (result.FurnitureStock[id] or 0) + 1
		return result
	end,
}
local function syncPlayer() synced += 1 end
-- PURCHASE_SOURCE --
root.CFrame = CFrame.new()
check(not buy(player, "Freezer") and saves == 0, "Remote purchase outside showroom must not save")
stand(anchors.Freezer)
check(not buy(player, "Register") and saves == 0, "Wrong display purchase must not save")
check(not buy(player, "Unknown") and saves == 0, "Invalid furniture must not save")
check(not buy(player, {}) and saves == 0, "Malformed furniture must not save")
check(buy(player, "Freezer"), "Freezer purchase at display must succeed")
check(profile.Cash == 1250 and profile.Angler.FurnitureStock.Freezer == 1, "Purchase must deduct the catalogue price and grant stock")
check(profile.Angler.Stats.CoinsSpent == 750 and synced == 1, "Purchase must update spending and synchronize")
stand(counter)
check(buy(player, "Register"), "Indoor counter purchase must succeed")
check(profile.Cash == 750 and profile.Angler.FurnitureStock.Register == 1, "Counter must charge the catalogue price")
stand(anchors.StorageRack)
failSave = true
check(not buy(player, "StorageRack"), "Failed saves must report failure")
check(profile.Cash == 750 and profile.Angler.FurnitureStock.StorageRack == nil, "Failed save must not change cash or stock")
failSave = false
check(buy(player, "StorageRack"), "Rack display purchase must succeed")
check(profile.Cash == 450 and profile.Angler.FurnitureStock.StorageRack == 1, "Rack must charge the catalogue price")
stand(anchors.Freezer)
local savesBefore = saves
check(not buy(player, "Freezer") and saves == savesBefore, "Insufficient cash must not save")
busy[player] = true
stand(anchors.StorageRack)
check(not buy(player, "StorageRack") and saves == savesBefore, "Concurrent purchases must be rejected")
busy[player] = nil
local loaded = profile
profile = nil
check(not buy(player, "StorageRack") and saves == savesBefore, "Unloaded profiles must not buy")
profile = loaded
print(string.format("Furniture showroom: %d authorization and purchase checks passed (recording mocks; no Roblox runtime).", checks))
