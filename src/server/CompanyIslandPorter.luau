-- The island branch of a hired porter walks catches up the terrace stairs to the
-- racks and kitchen storage the owner placed on the plot.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnglerData = require(script.Parent.AnglerData)
local BoatService = require(script.Parent.BoatService)
local CompanyService = require(script.Parent.CompanyService)
local CustomerService = require(script.Parent.CustomerService)
local Navigation = require(script.Parent.NpcNavigation)
local Catalog = require(ReplicatedStorage.Shared.AnglerCatalog)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local Layout = require(ReplicatedStorage.Shared.CompanyIslands)
local Porter = {}
local started = false
local states = {}

local function clear(state)
	if state.worker then
		state.worker.active = false
		state.worker.model:Destroy()
		state.worker = nil
	end
end

-- Just inside the plot gate, at the top of the stairs.
local function gate(island)
	return (island:GetAttribute("PlotFrame") * CFrame.new(0, 0, -26)).Position
end

-- Where to stand to use the first placed `itemId` on the plot, or the gate without one.
local function fixture(island, itemId)
	local plotFrame = island:GetAttribute("PlotFrame")
	local plot = island:FindFirstChild("PlotFurniture")
	for _, model in if plot then plot:GetChildren() else {} do
		if model:GetAttribute("ItemId") == itemId then
			local entry = { ItemId = itemId, X = model:GetAttribute("X"), Z = model:GetAttribute("Z"), R = model:GetAttribute("R") }
			return (Furniture.frame(plotFrame, entry, "Company") * CFrame.new(0, 0, Furniture.Items[itemId].Depth / 2 + 1.2)).Position
		end
	end
	return gate(island)
end

local function tick(island, state)
	local owner = Players:GetPlayerByUserId(island:GetAttribute("OwnerUserId") or 0)
	local profile = owner and BoatService.getProfile(owner)
	if not owner or not profile or not profile.Angler.Staff.Porter then
		clear(state)
		return
	end
	if state.owner ~= owner then clear(state); state.owner = owner end
	local frame = island:GetAttribute("IslandFrame")
	local function point(x, y, z) return (frame * Vector3.new(x, y, z)) end
	local foot, head = Layout.stairEnds(frame)
	if not state.worker or state.worker.humanoid.Health <= 0 then
		clear(state)
		local model = CustomerService.npc.spawn(point(30, 4.4, -82), "Porter")
		if island:GetAttribute("OwnerUserId") ~= owner.UserId or owner.Parent ~= Players then model:Destroy(); return end
		model.Name, model.Parent = "CompanyPorter", island
		state.worker = { model = model, humanoid = model:FindFirstChildOfClass("Humanoid"), root = model:FindFirstChild("HumanoidRootPart"), active = true }
	end
	local worker = state.worker
	local function valid()
		return worker.active and island.Parent ~= nil and island:GetAttribute("OwnerUserId") == owner.UserId and owner.Parent == Players
	end
	local function walk(position)
		return Navigation.walk(worker, position, valid, true)
	end
	local data = profile.Angler
	-- Refill the chef's prep table from saved storage even between fishing trips.
	local restock, stockPreview = {}, AnglerData.decode(data)
	for _, record in data.Storage do
		if AnglerData.canKitchenStorageAccept(stockPreview, record, Catalog.Fish) then
			table.insert(restock, record)
			table.insert(stockPreview.KitchenStorage.Fish, record)
		end
		if #restock == 6 then break end
	end
	if #restock > 0 then
		CustomerService.npc.bubble(worker, "Company porter · Restocking the kitchen")
		if frame:PointToObjectSpace(worker.root.Position).Y < 16 then
			if not walk(point(30, 4.4, -82)) or not walk(foot) or not walk(head) then return end
		end
		if not walk(fixture(island, "StorageRack")) or not walk(fixture(island, "KitchenStorage")) or not valid() then return end
		BoatService.updateProgress(owner, function(current)
			assert(valid() and current.Angler.Staff.Porter, "The island porter is no longer assigned.")
			for _, record in restock do
				local changed = AnglerData.restockFishToKitchenStorage(current.Angler, record, Catalog.Fish)
				if changed then current.Angler = changed end
			end
		end)
		return
	end
	local boatId, boat = CompanyService.mooredAtIsland(owner)
	if not boat then
		boatId, boat = BoatService.activeBoat(owner)
		local root = boat and boat.PrimaryPart
		local marker = island:FindFirstChild("BoatSpawn")
		if not root or not marker or (root.Position - marker.Position).Magnitude > 60 or root.AssemblyLinearVelocity.Magnitude > 2 then
			boatId, boat = nil, nil
		end
	end
	if not boat then
		CustomerService.npc.bubble(worker, "Company porter · Waiting for a docked boat")
		return
	end
	local hold = data.Holds[boatId] or {}
	local kitchen = false
	for _, item in hold do
		if item.Fish and AnglerData.canKitchenStorageAccept(data, item.Fish, Catalog.Fish) then kitchen = true; break end
	end
	local preview = AnglerData.decode(data)
	local load = {}
	for index, item in hold do
		if item.Fish then
			local fits = if kitchen then AnglerData.canKitchenStorageAccept(preview, item.Fish, Catalog.Fish)
				else #preview.Storage < AnglerData.storageCapacity(preview)
			if fits then
				table.insert(load, { Index = index, Fish = item.Fish })
				table.insert(if kitchen then preview.KitchenStorage.Fish else preview.Storage, item.Fish)
			end
		end
		if #load == 6 then break end
	end
	if #load == 0 then
		CustomerService.npc.bubble(worker, "Company porter · Waiting for catches or storage space")
		return
	end
	if frame:PointToObjectSpace(worker.root.Position).Y > 16 then
		if not walk(head) or not walk(foot) then return end
	end
	local pickup = boat:GetAttribute("PorterPickup") or point(30, 4.4, -144)
	if not walk(point(30, 4.4, -82)) or not walk(pickup) then return end
	CustomerService.npc.bubble(worker, "Company porter · Bringing catches to " .. (if kitchen then "the kitchen" else "storage"))
	local drop = fixture(island, if kitchen then "KitchenStorage" else "StorageRack")
	if not walk(point(30, 4.4, -82)) or not walk(foot)
		or not walk(head) or not walk(gate(island)) or not walk(drop) or not valid() then return end
	BoatService.updateProgress(owner, function(current)
		assert(valid() and current.Angler.Staff.Porter, "The island porter is no longer assigned.")
		-- Check the boat at delivery too. Cargo remains saved in its hold while carried.
		local companyId, companyBoat = CompanyService.mooredAtIsland(owner)
		local activeId, activeBoat = BoatService.activeBoat(owner)
		assert((companyId == boatId and companyBoat == boat) or (activeId == boatId and activeBoat == boat and boat.PrimaryPart and (boat.PrimaryPart.Position - island.BoatSpawn.Position).Magnitude <= 60 and boat.PrimaryPart.AssemblyLinearVelocity.Magnitude <= 2), "The boat left the company dock.")
		for index = #load, 1, -1 do
			local entry = load[index]
			local changed = if kitchen
				then AnglerData.unloadFishToKitchenStorage(current.Angler, boatId, entry.Index, entry.Fish, Catalog.Fish)
				else AnglerData.unloadFish(current.Angler, boatId, entry.Index, entry.Fish, true)
			if changed then current.Angler = changed end
		end
	end)
end

function Porter.start()
	if started then return end
	started = true
	task.spawn(function()
		while true do
			for _, island in CollectionService:GetTagged("CompanyIsland") do
				local state = states[island]
				if not state then state = {}; states[island] = state end
				if not state.busy then
					state.busy = true
					task.spawn(function()
						local ok, failure = pcall(tick, island, state)
						state.busy = false
						if not ok then warn("[Company porter] " .. tostring(failure)) end
					end)
				end
			end
			for island, state in states do
				if not island.Parent then clear(state); states[island] = nil end
			end
			task.wait(2)
		end
	end)
end

return Porter
