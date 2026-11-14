-- HARBOUR DIRECT, the online tool shop on the office PC (client WebShopApp, server
-- WebShopService). It needs the company's web shop license from Micro Harbour
-- (Shared.TechCatalog). Stock never runs out: crab cages and mussel nets are ordered in any
-- number that fits the base's tools racks. A small van brings an order DELIVERY_SECONDS after
-- it is placed and the goods go straight onto the tools racks (storage racks in Tools mode,
-- Angler.Furniture) in the base's storage room; instant delivery costs EXPRESS_MARKUP extra
-- and stocks the racks at once.
--
-- Pending orders are saved on the company profile as `WebShop` = { NextId = n, Orders = {
-- { Id, Item, Count, Paid, DueAt } } } so a van still comes after a rejoin. Every order holds
-- its rack space until it lands, so a delivery always fits; if racks were moved meanwhile, the
-- rest goes to carried stock and anything beyond that is refunded.
-- Pure Luau: no Roblox globals (scripts/check-web-shop.mjs runs it under lute).
local WebShop = {}

WebShop.NAME = "HARBOUR DIRECT"
WebShop.LICENSE = "WebShop"
WebShop.DELIVERY_SECONDS = 5 * 60
WebShop.EXPRESS_MARKUP = 0.5
WebShop.MAX_ORDERS = 5
WebShop.MAX_PER_ORDER = 48
-- Matches AnglerData.RACK_CAPACITY (tools on one rack) and CrabCages/MusselNets.MAX_STOCK.
WebShop.RACK_CAPACITY = 12
WebShop.MAX_CARRIED = 25

-- Prices match Tide & Tackle (Shared.CrabCages.PRICE, Shared.MusselNets.PRICE).
WebShop.Items = {
	CrabCage = {
		Name = "Crab cage",
		Spec = "3 hauls · a crab every 1-3 minutes",
		Price = 35,
		Field = "Cages", -- the tools rack's count
		Stock = "CrabCages", -- Angler.<Stock>.Stock, the carried pile
	},
	MusselNet = {
		Name = "Mussel net",
		Spec = "5 harvests · 2-5 mussels every 3-5 minutes",
		Price = 125,
		Field = "Nets",
		Stock = "MusselNets",
	},
}
WebShop.Order = { "CrabCage", "MusselNet" }

export type Order = { Id: number, Item: string, Count: number, Paid: number, DueAt: number }
export type Shop = { NextId: number, Orders: { Order } }

local function whole(value: any, low: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value < 2 ^ 53
end

-- Forgiving: broken or unknown orders are dropped rather than failing the save.
function WebShop.decode(raw: any): Shop
	local shop: Shop = { NextId = 1, Orders = {} }
	if type(raw) ~= "table" then
		return shop
	end
	if whole(raw.NextId, 1) then
		shop.NextId = raw.NextId
	end
	if type(raw.Orders) == "table" then
		for _, order in raw.Orders do
			if
				type(order) == "table"
				and whole(order.Id, 1)
				and type(order.Item) == "string"
				and WebShop.Items[order.Item]
				and whole(order.Count, 1)
				and order.Count <= WebShop.MAX_PER_ORDER
				and whole(order.Paid, 0)
				and whole(order.DueAt, 0)
				and #shop.Orders < WebShop.MAX_ORDERS
			then
				table.insert(shop.Orders, {
					Id = order.Id,
					Item = order.Item,
					Count = order.Count,
					Paid = order.Paid,
					DueAt = order.DueAt,
				})
				shop.NextId = math.max(shop.NextId, order.Id + 1)
			end
		end
	end
	table.sort(shop.Orders, function(a, b)
		return if a.DueAt == b.DueAt then a.Id < b.Id else a.DueAt < b.DueAt
	end)
	return shop
end

-- Plain table to save; nil once nothing is on its way (NextId only has to beat pending ids).
function WebShop.encode(shop: Shop): any
	if #shop.Orders == 0 then
		return nil
	end
	local orders = {}
	for _, order in shop.Orders do
		table.insert(orders, table.clone(order))
	end
	return { NextId = shop.NextId, Orders = orders }
end

function WebShop.price(itemId: string, count: number, instant: boolean?): number
	local base = WebShop.Items[itemId].Price * count
	return if instant then math.ceil(base * (1 + WebShop.EXPRESS_MARKUP)) else base
end

-- Tools racks at the base (storage racks switched to Tools mode), in placement order.
function WebShop.toolRacks(angler): { any }
	local racks = {}
	for _, entry in (angler and angler.Furniture) or {} do
		if entry.ItemId == "StorageRack" and entry.Mode == "Tools" then
			table.insert(racks, entry)
		end
	end
	return racks
end

-- Empty slots on the base's tools racks, before pending orders are counted.
function WebShop.rackSpace(angler): (number, number)
	local free, total = 0, 0
	for _, rack in WebShop.toolRacks(angler) do
		total += WebShop.RACK_CAPACITY
		free += math.max(0, WebShop.RACK_CAPACITY - (rack.Cages or 0) - (rack.Nets or 0))
	end
	return free, total
end

function WebShop.reserved(shop: Shop): number
	local count = 0
	for _, order in shop.Orders do
		count += order.Count
	end
	return count
end

-- Space a new order may still claim: empty rack slots minus what is already on its way.
function WebShop.available(profile): number
	local free = WebShop.rackSpace(profile.Angler)
	return math.max(0, free - WebShop.reserved(WebShop.decode(profile.WebShop)))
end

-- Why `profile` (the whole company profile) can't place this order, or nil.
function WebShop.orderProblem(profile, itemId: any, count: any, instant: any): string?
	local item = type(itemId) == "string" and WebShop.Items[itemId]
	if not item then
		return "Choose something from the shop."
	end
	if not whole(count, 1) or count > WebShop.MAX_PER_ORDER then
		return string.format("Order between 1 and %d at a time.", WebShop.MAX_PER_ORDER)
	end
	local shop = WebShop.decode(profile.WebShop)
	if not instant and #shop.Orders >= WebShop.MAX_ORDERS then
		return string.format("You already have %d deliveries on the way. Wait for a van first.", WebShop.MAX_ORDERS)
	end
	local _, total = WebShop.rackSpace(profile.Angler)
	if total == 0 then
		return "Deliveries go onto tools racks. Place a storage rack in your storage room and set it to Tools mode."
	end
	local space = WebShop.available(profile)
	if count > space then
		return if space == 0
			then "Your tools racks are full (or already booked by deliveries). Use some tools or add another tools rack."
			else string.format("Your tools racks only have room for %d more.", space)
	end
	local price = WebShop.price(itemId, count, instant == true)
	if (profile.Cash or 0) < price then
		return string.format("That costs $%d. Your company has $%d.", price, profile.Cash or 0)
	end
	return nil
end

-- Puts `count` of an item onto the tools racks in placement order, then into carried stock.
-- Returns how many went on racks, how many were carried and how many found no room.
function WebShop.stock(angler, itemId: string, count: number): (number, number, number)
	local item = WebShop.Items[itemId]
	local racked, carried = 0, 0
	local left = count
	for _, rack in WebShop.toolRacks(angler) do
		if left == 0 then
			break
		end
		local room = math.max(0, WebShop.RACK_CAPACITY - (rack.Cages or 0) - (rack.Nets or 0))
		local put = math.min(room, left)
		if put > 0 then
			rack[item.Field] = (rack[item.Field] or 0) + put
			racked += put
			left -= put
		end
	end
	local pile = angler[item.Stock]
	if left > 0 and type(pile) == "table" and type(pile.Stock) == "number" then
		local put = math.max(0, math.min(WebShop.MAX_CARRIED - pile.Stock, left))
		pile.Stock += put
		carried += put
		left -= put
	end
	return racked, carried, left
end

local function refund(profile, order: Order, missing: number): number
	if missing <= 0 then
		return 0
	end
	local amount = math.floor(order.Paid * missing / order.Count)
	profile.Cash += amount
	local stats = profile.Angler.Stats
	stats.CoinsSpent = math.max(0, (stats.CoinsSpent or 0) - amount)
	return amount
end

export type Delivery = { Item: string, Count: number, Racked: number, Carried: number, Refund: number, Instant: boolean }

-- Takes payment and either queues the order (DueAt = now + DELIVERY_SECONDS) or, with
-- `instant`, stocks the racks right away. Mutates the profile copy inside a save.
function WebShop.order(profile, itemId: string, count: number, instant: boolean, now: number): (Order?, Delivery?)
	local problem = WebShop.orderProblem(profile, itemId, count, instant)
	assert(problem == nil, problem)
	local price = WebShop.price(itemId, count, instant)
	profile.Cash -= price
	profile.Angler.Stats.CoinsSpent = (profile.Angler.Stats.CoinsSpent or 0) + price
	local shop = WebShop.decode(profile.WebShop)
	local order: Order = { Id = shop.NextId, Item = itemId, Count = count, Paid = price, DueAt = now + WebShop.DELIVERY_SECONDS }
	shop.NextId += 1
	if instant then
		local racked, carried, missing = WebShop.stock(profile.Angler, itemId, count)
		local delivery = {
			Item = itemId,
			Count = count,
			Racked = racked,
			Carried = carried,
			Refund = refund(profile, order, missing),
			Instant = true,
		}
		return nil, delivery
	end
	table.insert(shop.Orders, order)
	profile.WebShop = WebShop.encode(shop)
	return order, nil
end

function WebShop.find(shop: Shop, id: any): (number?, Order?)
	for index, order in shop.Orders do
		if order.Id == id then
			return index, order
		end
	end
	return nil, nil
end

-- The van has arrived: unload order `id` onto the racks. Errors if it was already delivered.
function WebShop.deliver(profile, id: number): Delivery
	local shop = WebShop.decode(profile.WebShop)
	local index, order = WebShop.find(shop, id)
	assert(index and order, "That delivery has already arrived")
	table.remove(shop.Orders, index)
	profile.WebShop = WebShop.encode(shop)
	local racked, carried, missing = WebShop.stock(profile.Angler, order.Item, order.Count)
	return {
		Item = order.Item,
		Count = order.Count,
		Racked = racked,
		Carried = carried,
		Refund = refund(profile, order, missing),
		Instant = false,
	}
end

-- One line for the player about a finished delivery.
function WebShop.describe(delivery: Delivery): string
	local item = WebShop.Items[delivery.Item]
	local noun = string.lower(item.Name) .. (if delivery.Count == 1 then "" else "s")
	local text = string.format(
		"%s: %d %s %s on your tools racks.",
		if delivery.Instant then "Instant delivery" else "Your van has arrived",
		delivery.Count,
		noun,
		if delivery.Racked ~= delivery.Count then "were ordered;" elseif delivery.Count == 1 then "is" else "are"
	)
	if delivery.Racked ~= delivery.Count then
		text = string.format("%s %d went on your tools racks", text, delivery.Racked)
		if delivery.Carried > 0 then
			text ..= string.format(", %d into your carried stock", delivery.Carried)
		end
		if delivery.Refund > 0 then
			text ..= string.format(" and $%d was refunded for the rest", delivery.Refund)
		end
		text ..= "."
	end
	return text
end

return WebShop
