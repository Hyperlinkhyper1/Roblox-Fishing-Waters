-- HARBOUR DIRECT, the online tool shop on the office PC (client WebShopApp, Shared.WebShop).
-- Orders need the company's web shop license (Shared.TechCatalog) and, like the other PC
-- apps, are only taken while the player sits at one of their own office PCs
-- (OfficeComputerService.atDesk). Stock never runs out.
--
-- A normal order is saved on the company profile and a HARBOUR DIRECT van (Map/DeliveryVan)
-- turns up on the ring road outside the base DELIVERY_SECONDS later. It parks by the base's
-- crossing, opens its back doors and the parcels fly onto the base's tools racks, which is
-- the moment the order is saved as delivered. Instant orders cost 50% more and go straight
-- onto the racks. Orders due while nobody from the company is online arrive on the next visit.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatService = require(script.Parent.BoatService)
local FurnitureService = require(script.Parent.FurnitureService)
local OfficeComputerService = require(script.Parent.OfficeComputerService)
local DeliveryVan = require(script.Parent.Map.DeliveryVan)
local Furniture = require(ReplicatedStorage.Shared.FurnitureCatalog)
local TechCatalog = require(ReplicatedStorage.Shared.TechCatalog)
local WebShop = require(ReplicatedStorage.Shared.WebShop)

local Service = {}
local started = false

local BASE_TAG = "PlayerBase"
-- The van's lane on the ring road in front of the base, in house-local studs (the base's
-- zebra crossing spans z = 46..58 at x = 0; Map/BaseHouse).
local LANE_Z = 48.5
local PARK_X = -12 -- front bumper stops just short of the crossing
local ROUTE_X = 90 -- where the van appears and disappears along the road
local ROAD_Y = -0.19 -- the road's top in house-local studs, if the raycast finds nothing
local DRIVE_IN, DRIVE_OUT = 8, 7
-- The van sets off this long before an order is due so it parks right on time.
local LEAD = DRIVE_IN + 1
local MAX_PARCELS_PER_RACK = 3

local notice: RemoteEvent
-- Company key -> true while that company's van is on the road.
local onTheRoad: { [string]: boolean } = {}

local function companyKey(player: Player): string
	local id = player:GetAttribute("CompanyId")
	return if type(id) == "string" and id ~= "" then id else "user:" .. player.UserId
end

local function baseOf(player: Player): Model?
	for _, base in CollectionService:GetTagged(BASE_TAG) do
		if base:GetAttribute("OwnerUserId") == player.UserId and base:IsA("Model") then
			return base
		end
	end
	return nil
end

local function houseFrameOf(base: Model): CFrame?
	local house = base:FindFirstChild("BaseHouse")
	local frame = house and house:GetAttribute("HouseFrame")
	return if typeof(frame) == "CFrame" then frame else nil
end

local function tell(player: Player, message: string)
	if player.Parent == Players then
		notice:FireClient(player, message)
	end
end

local function licensed(profile): boolean
	return TechCatalog.hasLicense(profile, WebShop.LICENSE)
end

local function state(player: Player)
	local profile = BoatService.getProfile(player)
	if not profile then
		return { Ok = false, Message = "Your company is still loading." }
	end
	local shop = WebShop.decode(profile.WebShop)
	local free, total = WebShop.rackSpace(profile.Angler)
	local items = {}
	for _, id in WebShop.Order do
		local item = WebShop.Items[id]
		table.insert(items, {
			Id = id,
			Name = item.Name,
			Spec = item.Spec,
			Price = item.Price,
			Carried = profile.Angler[item.Stock].Stock,
		})
	end
	local orders = {}
	for _, order in shop.Orders do
		table.insert(orders, { Id = order.Id, Item = order.Item, Count = order.Count, DueAt = order.DueAt })
	end
	return {
		Ok = true,
		Licensed = licensed(profile),
		Cash = profile.Cash,
		Items = items,
		Orders = orders,
		Free = free,
		Total = total,
		Available = WebShop.available(profile),
		MaxOrders = WebShop.MAX_ORDERS,
		MaxPerOrder = WebShop.MAX_PER_ORDER,
		DeliverySeconds = WebShop.DELIVERY_SECONDS,
		Markup = WebShop.EXPRESS_MARKUP,
		Now = os.time(),
	}
end

local function order(player: Player, itemId: any, count: any, instant: any)
	if not OfficeComputerService.atDesk(player) then
		return { Ok = false, Message = "Sit at your office PC to shop online." }
	end
	local profile = BoatService.getProfile(player)
	if not profile then
		return { Ok = false, Message = "Your company is still loading." }
	end
	if not licensed(profile) then
		return { Ok = false, Message = "The web shop needs a license from " .. TechCatalog.STORE_NAME .. " in the city." }
	end
	instant = instant == true
	local problem = WebShop.orderProblem(profile, itemId, count, instant)
	if problem then
		local result = state(player)
		result.Ok, result.Message = false, problem
		return result
	end
	local delivery
	local ok, message = BoatService.updateProgress(player, function(current)
		-- UpdateAsync may retry: the order rules run against the stored profile.
		assert(licensed(current), "No web shop license")
		local _, done = WebShop.order(current, itemId, count, instant, os.time())
		delivery = done
	end)
	if not ok then
		local result = state(player)
		result.Ok, result.Message = false, message
		return result
	end
	local result = state(player)
	if delivery then
		FurnitureService.refreshPlayer(player)
		result.Message = WebShop.describe(delivery)
	else
		local item = WebShop.Items[itemId]
		result.Message = string.format(
			"Order placed: %d %s%s. A van brings it to your tools racks in %d minutes.",
			count,
			string.lower(item.Name),
			if count == 1 then "" else "s",
			WebShop.DELIVERY_SECONDS // 60
		)
	end
	return result
end

----------------------------------------------------------------------------------------------------
-- Deliveries

-- Where each parcel lands: the tools racks the delivery fills, in the order WebShop.stock fills
-- them, at most a few parcels per rack.
local function parcelTargets(profile, houseFrame: CFrame, due: { WebShop.Order }): { Vector3 }
	local remaining = 0
	for _, entry in due do
		remaining += entry.Count
	end
	local targets = {}
	for _, rack in WebShop.toolRacks(profile.Angler) do
		if remaining <= 0 then
			break
		end
		local room = math.max(0, WebShop.RACK_CAPACITY - (rack.Cages or 0) - (rack.Nets or 0))
		local put = math.min(room, remaining)
		if put > 0 then
			remaining -= put
			local frame = Furniture.frame(houseFrame, rack, nil)
			for index = 1, math.min(put, MAX_PARCELS_PER_RACK) do
				table.insert(targets, (frame * CFrame.new((index - 2) * 1.0, 1 + index * 1.3, 0.4)).Position)
			end
		end
	end
	return targets
end

local function roadY(houseFrame: CFrame, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local above = houseFrame * Vector3.new(PARK_X, 8, LANE_Z)
	local hit = workspace:Raycast(above, Vector3.new(0, -24, 0), params)
	local y = if hit then hit.Position.Y - houseFrame.Position.Y else ROAD_Y
	-- A lamp post or kerb clutter is not the road.
	return if y > 1.5 or y < -4 then ROAD_Y else y
end

local function vanFolder(): Folder
	local folder = workspace:FindFirstChild("DeliveryVans")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DeliveryVans"
		folder.Parent = workspace
	end
	return folder :: Folder
end

local function laneFrame(houseFrame: CFrame, x: number, y: number): CFrame
	-- Facing house-local +X along the road.
	return houseFrame * CFrame.new(x, y, LANE_Z) * CFrame.Angles(0, -math.pi / 2, 0)
end

-- Saves every order in `ids` as delivered. Returns the deliveries, or nil if it didn't save.
local function unload(player: Player, ids: { number }): { WebShop.Delivery }?
	local deliveries
	local ok = BoatService.updateProgress(player, function(current)
		deliveries = {}
		local shop = WebShop.decode(current.WebShop)
		for _, id in ids do
			if WebShop.find(shop, id) then
				table.insert(deliveries, WebShop.deliver(current, id))
				shop = WebShop.decode(current.WebShop)
			end
		end
		assert(#deliveries > 0, "Those deliveries have already arrived")
	end)
	return if ok then deliveries else nil
end

local function finish(player: Player, deliveries: { WebShop.Delivery })
	FurnitureService.refreshPlayer(player)
	for _, delivery in deliveries do
		tell(player, WebShop.describe(delivery))
	end
end

-- One van trip for `player`: drive in, unload every order due by the time it parks, drive off.
local function deliver(player: Player, key: string)
	local profile = BoatService.getProfile(player)
	if not profile then
		return
	end
	local base = baseOf(player)
	local houseFrame = base and houseFrameOf(base)
	local van: Model? = nil
	local parked: CFrame? = nil
	if base and houseFrame then
		local ignore = {}
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		local y = roadY(houseFrame, ignore)
		local start = laneFrame(houseFrame, -ROUTE_X, y)
		parked = laneFrame(houseFrame, PARK_X, y)
		local built = DeliveryVan.build(vanFolder(), start)
		van = built
		DeliveryVan.fade(built, true, 1)
		DeliveryVan.drive(built, start, parked :: CFrame, DRIVE_IN, Enum.EasingDirection.Out)
	else
		-- No harbour base in this server to drive to: the goods still land on time.
		local first = WebShop.decode(profile.WebShop).Orders[1]
		task.wait(if first then math.max(0, first.DueAt - os.time()) else 0)
	end
	-- Everything due by now rides in this van.
	local current = BoatService.getProfile(player)
	local now = os.time()
	local due, ids = {}, {}
	for _, entry in (if current then WebShop.decode(current.WebShop).Orders else {}) do
		if entry.DueAt <= now + 1 then
			table.insert(due, entry)
			table.insert(ids, entry.Id)
		end
	end
	if #ids > 0 and player.Parent == Players then
		if van and parked and van.Parent and current and houseFrame then
			DeliveryVan.doors(van, parked, true, 0.6)
			local targets = parcelTargets(current, houseFrame, due)
			local deliveries = unload(player, ids)
			if deliveries then
				local waiting = #targets
				if waiting == 0 then
					finish(player, deliveries)
				end
				for index, target in targets do
					task.delay((index - 1) * 0.22, function()
						if not van.Parent then
							return
						end
						DeliveryVan.parcel(van, parked, target, function()
							waiting -= 1
							if waiting == 0 then
								finish(player, deliveries)
							end
						end)
					end)
				end
				task.wait(math.max(1.2, #targets * 0.22 + 1.6))
			end
			DeliveryVan.doors(van, parked, false, 0.5)
			task.wait(0.4)
		else
			local deliveries = unload(player, ids)
			if deliveries then
				finish(player, deliveries)
			end
		end
	end
	if van and parked and van.Parent then
		local leave = laneFrame(houseFrame :: CFrame, ROUTE_X, parked.Position.Y - (houseFrame :: CFrame).Position.Y)
		task.delay(DRIVE_OUT - 1.5, function()
			if van.Parent then
				DeliveryVan.fade(van, false, 1.4)
			end
		end)
		DeliveryVan.drive(van, parked, leave, DRIVE_OUT, Enum.EasingDirection.In)
		van:Destroy()
	elseif van then
		van:Destroy()
	end
	onTheRoad[key] = nil
end

-- Starts a van for any company whose next order is (nearly) due. One van per company at a time;
-- whichever member is online first receives it at their base.
local function dispatch()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local key = companyKey(player)
		if onTheRoad[key] then
			continue
		end
		local profile = BoatService.getProfile(player)
		local orders = profile and WebShop.decode(profile.WebShop).Orders
		local first = orders and orders[1]
		if first and now >= first.DueAt - LEAD then
			onTheRoad[key] = true
			task.spawn(function()
				local ok, failure = pcall(deliver, player, key)
				if not ok then
					warn("[WebShop] Delivery failed: " .. tostring(failure))
					onTheRoad[key] = nil
				end
			end)
		end
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "WebShop"
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Request"
	remote.Parent = folder
	notice = Instance.new("RemoteEvent")
	notice.Name = "Notice"
	notice.Parent = folder
	folder.Parent = ReplicatedStorage

	local lastRequest: { [Player]: number } = {}
	remote.OnServerInvoke = function(player, action, itemId, count, instant)
		if os.clock() - (lastRequest[player] or -math.huge) < 0.3 then
			return { Ok = false, Message = "One moment..." }
		end
		lastRequest[player] = os.clock()
		if action == "State" then
			return state(player)
		elseif action == "Order" then
			return order(player, itemId, count, instant)
		end
		return { Ok = false, Message = "Unknown request." }
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			local ok, failure = pcall(dispatch)
			if not ok then
				warn("[WebShop] " .. tostring(failure))
			end
		end
	end)
end

return Service
