-- HARBOUR DIRECT: the online tool shop on the office PC (opened by OfficeComputer once the
-- company owns the web shop license). Crab cages and mussel nets never sell out; pick how
-- many, then ORDER (a van brings them onto your tools racks in 5 minutes) or INSTANT (50%
-- extra, on the racks straight away). The right-hand column shows the tools racks' free space
-- and every van on its way. Orders go to WebShopService, which only takes them while you sit
-- at your own PC. `start` shows the van's arrival notices wherever you are.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local RetroUI = require(script.Parent.RetroUI)
local Stocks = require(ReplicatedStorage.Shared.Stocks)
local WebShop = require(ReplicatedStorage.Shared.WebShop)

local WebShopApp = {}
WebShopApp.TITLE = WebShop.NAME
WebShopApp.SUBTITLE = "ONLINE TOOL SHOP"
WebShopApp.READY = "IN STOCK, ALWAYS. VAN DELIVERY IN 5 MINUTES, OR INSTANT FOR 50% EXTRA."

local C = RetroUI.Colors
local px = UDim2.fromOffset
local RIGHT, CENTER = Enum.TextXAlignment.Right, Enum.TextXAlignment.Center
local POLL = 4

export type App = { destroy: () -> () }

local function signature(state: any): string
	local parts = { tostring(state.Cash), tostring(state.Free), tostring(state.Total), tostring(state.Available) }
	for _, item in state.Items or {} do
		table.insert(parts, tostring(item.Carried))
	end
	for _, entry in state.Orders or {} do
		table.insert(parts, entry.Id .. ":" .. entry.DueAt)
	end
	return table.concat(parts, ",")
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function WebShopApp.mount(content: Frame, onStatus: (string) -> ()): App
	local alive = true
	local connections: { RBXScriptConnection } = {}
	local app = {}
	function app.destroy()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
	end

	local folder = ReplicatedStorage:WaitForChild("WebShop", 10)
	local remote = folder and folder:WaitForChild("Request", 10)
	if not alive then
		return app
	end
	if not remote or not remote:IsA("RemoteFunction") then
		RetroUI.text(content, "Offline", WebShop.NAME .. " IS OFFLINE.\nTRY AGAIN IN A MOMENT.", px(0, 0), UDim2.fromScale(1, 1), {
			AlignX = CENTER,
			Wrap = true,
			Size = 22,
		})
		return app
	end

	local busy = false
	local page: Frame? = nil
	local latest: any = nil
	local receivedAt = os.clock()
	local quantities: { [string]: number } = {}
	-- Countdown labels: { Label, DueAt } refreshed every half second.
	local countdowns: { { Label: TextLabel, DueAt: number } } = {}
	local sincePoll = 0

	local function call(action: string, ...: any)
		local ok, result = pcall(remote.InvokeServer, remote, action, ...)
		if not ok or type(result) ~= "table" then
			return { Ok = false, Message = "THE SHOP DIDN'T ANSWER. TRY AGAIN." }
		end
		return result
	end

	local function serverNow(): number
		return (if latest then latest.Now else os.time()) + (os.clock() - receivedAt)
	end

	local function paintCountdowns()
		local now = serverNow()
		for _, entry in countdowns do
			local left = entry.DueAt - now
			entry.Label.Text = if left > 0 then "ARRIVES IN " .. clock(left) else "VAN AT YOUR DOOR..."
		end
	end

	local render: (any) -> ()

	local function place(itemId: string, instant: boolean)
		if busy then
			return
		end
		busy = true
		local count = quantities[itemId] or 1
		onStatus(if instant then "PAYING FOR INSTANT DELIVERY..." else "PLACING YOUR ORDER...")
		local response = call("Order", itemId, count, instant)
		busy = false
		if not alive then
			return
		end
		onStatus(string.upper(tostring(response.Message or (if response.Ok then "DONE." else "THAT DIDN'T WORK."))))
		if response.Items then
			quantities[itemId] = 1
			render(response)
		end
	end

	local function productCard(frame: Frame, item: any, index: number, state: any)
		local y = 56 + (index - 1) * 176
		local card = RetroUI.frame(frame, "Item" .. item.Id, px(24, y), px(448, 164), {
			BackgroundTransparency = 0,
			BackgroundColor3 = C.Panel,
		})
		RetroUI.border(card, C.Bright, 2)
		RetroUI.text(card, "Name", string.upper(item.Name), px(16, 8), px(260, 28), {
			Font = RetroUI.Fonts.Title,
			Size = 15,
			Color = C.Hot,
		})
		RetroUI.text(card, "Stock", "IN STOCK: UNLIMITED", px(250, 8), px(184, 28), {
			Size = 14,
			Color = C.Mid,
			AlignX = RIGHT,
		})
		RetroUI.text(card, "Spec", string.upper(item.Spec), px(16, 36), px(420, 22), { Size = 15, Color = C.Mid })
		RetroUI.text(
			card,
			"Price",
			string.format("%s EACH  ·  YOU CARRY %d", Stocks.money(item.Price), item.Carried or 0),
			px(16, 60),
			px(420, 22),
			{ Size = 16 }
		)

		local most = math.max(1, math.min(state.MaxPerOrder or WebShop.MAX_PER_ORDER, state.Available or 0))
		local count = math.clamp(quantities[item.Id] or 1, 1, most)
		quantities[item.Id] = count
		local amount = RetroUI.text(card, "Count", tostring(count), px(56, 96), px(56, 32), {
			Font = RetroUI.Fonts.Title,
			Size = 16,
			AlignX = CENTER,
		})
		local order, instant
		local function paint()
			local normal = WebShop.price(item.Id, count, false)
			local express = WebShop.price(item.Id, count, true)
			amount.Text = tostring(count)
			order:setText(string.format("ORDER %s · 5 MIN", Stocks.money(normal)))
			instant:setText(string.format("INSTANT %s", Stocks.money(express)))
			local room = (state.Available or 0) >= count
			local slots = #state.Orders < (state.MaxOrders or WebShop.MAX_ORDERS)
			order:setEnabled(room and slots and (state.Cash or 0) >= normal)
			instant:setEnabled(room and (state.Cash or 0) >= express)
		end
		local function set(value: number)
			count = math.clamp(value, 1, most)
			quantities[item.Id] = count
			paint()
		end
		RetroUI.button(card, "Less", "-", px(16, 96), px(36, 32), function()
			set(count - 1)
		end, { Font = RetroUI.Fonts.Title, Size = 16 })
		RetroUI.button(card, "More", "+", px(116, 96), px(36, 32), function()
			set(count + 1)
		end, { Font = RetroUI.Fonts.Title, Size = 16 })
		RetroUI.button(card, "Max", "MAX", px(158, 96), px(62, 32), function()
			set(most)
		end, { Size = 16 })
		order = RetroUI.button(card, "Order", "", px(230, 90), px(204, 30), function()
			place(item.Id, false)
		end, { Size = 16 })
		instant = RetroUI.button(card, "Instant", "", px(230, 126), px(204, 30), function()
			place(item.Id, true)
		end, { Size = 16 })
		paint()
	end

	render = function(result)
		if not alive then
			return
		end
		if page then
			page:Destroy()
		end
		table.clear(countdowns)
		local frame = RetroUI.frame(content, "Page", px(0, 0), UDim2.fromScale(1, 1))
		page = frame
		if result.Ok == false and type(result.Items) ~= "table" then
			RetroUI.text(frame, "Error", string.upper(tostring(result.Message or "Could not load the shop.")), px(24, 24), px(720, 80), {
				Wrap = true,
				Size = 20,
			})
			return
		end
		latest, receivedAt = result, os.clock()
		RetroUI.text(frame, "Heading", WebShop.NAME .. "  ·  FISHING GEAR, DELIVERED", px(24, 10), px(480, 30), {
			Font = RetroUI.Fonts.Title,
			Size = 14,
		})
		RetroUI.text(frame, "Cash", "CASH " .. Stocks.money(result.Cash or 0), px(470, 10), px(274, 30), {
			Size = 20,
			Color = C.Mid,
			AlignX = RIGHT,
		})
		RetroUI.rule(frame, "HeadingRule", px(24, 44), UDim.new(0, 720), C.Mid)

		for index, item in result.Items do
			productCard(frame, item, index, result)
		end

		-- Right column: the tools racks and the vans on their way.
		local side = RetroUI.frame(frame, "Deliveries", px(488, 56), px(256, 340))
		RetroUI.text(side, "RackTitle", "YOUR TOOLS RACKS", px(0, 0), px(256, 24), {
			Font = RetroUI.Fonts.Title,
			Size = 13,
			Color = C.Hot,
		})
		if (result.Total or 0) == 0 then
			RetroUI.text(
				side,
				"NoRack",
				"NO TOOLS RACK YET.\nPLACE A STORAGE RACK IN YOUR STORAGE ROOM AND SET IT TO TOOLS MODE IN BUILD MODE (B).",
				px(0, 28),
				px(256, 96),
				{ Size = 15, Wrap = true, AlignY = Enum.TextYAlignment.Top }
			)
		else
			RetroUI.text(side, "Free", string.format("EMPTY SLOTS  %d / %d", result.Free or 0, result.Total or 0), px(0, 28), px(256, 22), {
				Size = 16,
			})
			RetroUI.text(side, "Room", string.format("ROOM TO ORDER  %d", result.Available or 0), px(0, 52), px(256, 22), {
				Size = 16,
				Color = if (result.Available or 0) > 0 then C.Bright else C.Hot,
			})
		end
		RetroUI.rule(side, "Rule", px(0, 128), UDim.new(1, 0), C.Dim)
		RetroUI.text(
			side,
			"VanTitle",
			string.format("ON THE WAY  %d/%d", #result.Orders, result.MaxOrders or WebShop.MAX_ORDERS),
			px(0, 136),
			px(256, 24),
			{ Font = RetroUI.Fonts.Title, Size = 13, Color = C.Hot }
		)
		if #result.Orders == 0 then
			RetroUI.text(side, "None", "NOTHING ON ITS WAY.", px(0, 164), px(256, 22), { Size = 15, Color = C.Mid })
		end
		for index, entry in result.Orders do
			local y = 164 + (index - 1) * 36
			local item = WebShop.Items[entry.Item]
			local name = if item then string.upper(item.Name) else "PARCEL"
			RetroUI.text(side, "Order" .. index, string.format("%d x %s%s", entry.Count, name, if entry.Count == 1 then "" else "S"), px(0, y), px(256, 18), {
				Size = 15,
			})
			local label = RetroUI.text(side, "Due" .. index, "", px(12, y + 16), px(244, 18), { Size = 14, Color = C.Mid })
			table.insert(countdowns, { Label = label, DueAt = entry.DueAt })
		end
		paintCountdowns()

		RetroUI.rule(frame, "FootRule", px(24, 412), UDim.new(0, 720), C.Dim)
		RetroUI.text(
			frame,
			"Terms",
			string.format(
				"VAN DELIVERY IN %d MINUTES, STRAIGHT ONTO THE TOOLS RACKS IN YOUR STORAGE ROOM. INSTANT DELIVERY COSTS %d%% EXTRA.",
				(result.DeliverySeconds or WebShop.DELIVERY_SECONDS) // 60,
				math.round((result.Markup or WebShop.EXPRESS_MARKUP) * 100)
			),
			px(24, 418),
			px(720, 56),
			{ Size = 14, Color = C.Mid, Wrap = true }
		)
	end

	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(step)
			sincePoll += step
			paintCountdowns()
			if sincePoll >= POLL and not busy then
				sincePoll = 0
				task.spawn(function()
					local fresh = call("State")
					if not alive or busy or not fresh.Items then
						return
					end
					-- Redraw only when something changed, so a hovered button doesn't flicker.
					if latest and signature(fresh) == signature(latest) then
						latest, receivedAt = fresh, os.clock()
					else
						render(fresh)
					end
				end)
			end
		end)
	)

	render(call("State"))
	return app
end

-- Van arrival notices, shown wherever the player is.
function WebShopApp.start()
	local folder = ReplicatedStorage:WaitForChild("WebShop", 60)
	local notice = folder and folder:WaitForChild("Notice", 30)
	if not notice or not notice:IsA("RemoteEvent") then
		return
	end
	notice.OnClientEvent:Connect(function(message)
		if type(message) == "string" then
			pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
				Title = WebShop.NAME,
				Text = message,
				Duration = 6,
			})
		end
	end)
end

return WebShopApp
