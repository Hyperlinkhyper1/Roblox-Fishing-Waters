-- Harbour Exchange: the investment app on the office PC (opened by OfficeComputer). Three pages:
-- MARKET (live list, chart, buy/sell), PORTFOLIO (holdings and profit) and DIVIDENDS (countdown
-- to the next weekly payout and recent payouts). Prices arrive as attributes on
-- ReplicatedStorage.StockMarket every tick; orders go to StockMarketService, which only accepts
-- them while you sit at your own computer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RetroUI = require(script.Parent.RetroUI)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Stocks = require(ReplicatedStorage.Shared.Stocks)

local StockApp = {}
StockApp.TITLE = "HARBOUR EXCHANGE"

local C = RetroUI.Colors
local px = UDim2.fromOffset
local LEFT, RIGHT, CENTER = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center

local UP, DOWN, FLAT = "▲", "▼", "="

local function arrow(delta: number): string
	return if delta > 1e-6 then UP elseif delta < -1e-6 then DOWN else FLAT
end

local function percent(delta: number, base: number): string
	local value = if base > 0 then delta / base * 100 else 0
	return string.format("%s%.2f%%", arrow(delta), math.abs(value))
end

local function signedMoney(amount: number): string
	return (if amount > 0.5 then "+" else "") .. Stocks.money(amount)
end

-- In-game duration ("2D 05H 12M") for `seconds` real seconds.
local function gameDuration(seconds: number): string
	local ingame = math.max(0, math.floor(seconds * Stocks.GAME_SPEED))
	local days = math.floor(ingame / 86400)
	local hours = math.floor(ingame % 86400 / 3600)
	local minutes = math.floor(ingame % 3600 / 60)
	return string.format("%dD %02dH %02dM", days, hours, minutes)
end

local function realDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm %02ds", minutes, seconds % 60)
end

export type App = { destroy: () -> () }

function StockApp.mount(content: Frame, onStatus: (string) -> ()): App
	local player = Players.LocalPlayer
	local connections: { RBXScriptConnection } = {}
	local alive = true
	local function connect(signal: RBXScriptSignal, handler: (...any) -> ())
		table.insert(connections, signal:Connect(handler))
	end
	local app = {}
	function app.destroy()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local market = ReplicatedStorage:WaitForChild("StockMarket", 10)
	local request = market and market:WaitForChild("Request", 10)
	if not alive then
		return app
	end
	if not market or not request or not request:IsA("RemoteFunction") then
		RetroUI.text(
			content,
			"Offline",
			"THE EXCHANGE IS OFFLINE.\nTRY AGAIN IN A MOMENT.",
			px(0, 0),
			UDim2.fromScale(1, 1),
			{
				AlignX = CENTER,
				Wrap = true,
				Size = 22,
			}
		)
		return app
	end
	local remote = request :: RemoteFunction

	local state = {
		Cash = player:GetAttribute("Cash") or 0,
		Portfolio = Stocks.decode(nil),
		NextPayout = nil :: number?,
		Loaded = false,
	}
	local selected = Stocks.Companies[1].Ticker
	local rangeId = "Live"
	local page = "Market"
	local quantity = 1
	local pending = false
	local message, messageGood, messageUntil = "", true, 0

	local function price(ticker: string): number
		return market:GetAttribute("P_" .. ticker) or Stocks.byTicker[ticker].Base
	end
	local function open(ticker: string): number
		return market:GetAttribute("O_" .. ticker) or price(ticker)
	end
	local function owned(ticker: string): number
		local holding = state.Portfolio.Holdings[ticker]
		return if holding then holding.Shares else 0
	end
	local function prices(): { [string]: number }
		local result = {}
		for _, company in Stocks.Companies do
			result[company.Ticker] = price(company.Ticker)
		end
		return result
	end

	----------------------------------------------------------------------------------------------
	-- Tabs

	local pages: { [string]: Frame } = {}
	local tabs: { [string]: RetroUI.Button } = {}
	local render: { [string]: () -> () } = {}
	local function show(id: string)
		page = id
		for name, frame in pages do
			frame.Visible = name == id
			tabs[name]:setSelected(name == id)
		end
		render[id]()
	end
	for index, spec in
		{ { "Market", "MARKET", 140 }, { "Portfolio", "PORTFOLIO", 160 }, { "Dividends", "DIVIDENDS", 160 } }
	do
		local x = ({ 12, 160, 328 })[index]
		tabs[spec[1]] = RetroUI.button(content, spec[1] .. "Tab", spec[2], px(x, 8), px(spec[3], 30), function()
			show(spec[1])
		end, { Font = RetroUI.Fonts.Title, Size = 16 })
		pages[spec[1]] = RetroUI.frame(content, spec[1], px(0, 46), UDim2.new(1, 0, 0, 432), { Visible = false })
	end
	local cashLabel = RetroUI.text(content, "Cash", "", px(500, 8), px(256, 30), { AlignX = RIGHT, Size = 20 })
	local function paintCash()
		cashLabel.Text = "CASH " .. Stocks.money(state.Cash)
	end

	----------------------------------------------------------------------------------------------
	-- MARKET

	local marketPage = pages.Market
	local list = RetroUI.frame(marketPage, "List", px(12, 0), px(292, 432))
	RetroUI.border(list, C.Dim, 2)
	RetroUI.text(list, "HeadTicker", "TICKER", px(10, 0), px(90, 28), { Size = 16, Color = C.Mid })
	RetroUI.text(list, "HeadPrice", "PRICE", px(96, 0), px(100, 28), { Size = 16, Color = C.Mid, AlignX = RIGHT })
	RetroUI.text(list, "HeadDay", "DAY", px(196, 0), px(84, 28), { Size = 16, Color = C.Mid, AlignX = RIGHT })
	RetroUI.rule(list, "HeadRule", px(0, 28), UDim.new(1, 0))
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Rows"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Position = px(0, 30)
	scroller.Size = UDim2.new(1, 0, 1, -30)
	scroller.CanvasSize = px(0, #Stocks.Companies * 34)
	scroller.ScrollBarThickness = 8
	scroller.ScrollBarImageColor3 = C.Mid
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.Parent = list

	type Row = { Button: TextButton, Ticker: TextLabel, Price: TextLabel, Day: TextLabel, Hover: boolean }
	local rows: { [string]: Row } = {}
	local paintRows: () -> ()
	local selectStock: (string) -> ()
	for index, company in Stocks.Companies do
		local button = Instance.new("TextButton")
		button.Name = company.Ticker
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = C.Bright
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Position = px(0, (index - 1) * 34)
		button.Size = UDim2.new(1, -10, 0, 34)
		button.Parent = scroller
		local row: Row = {
			Button = button,
			Ticker = RetroUI.text(button, "Ticker", company.Ticker, px(10, 0), px(90, 34), { Size = 20 }),
			Price = RetroUI.text(button, "Price", "", px(96, 0), px(100, 34), { Size = 20, AlignX = RIGHT }),
			Day = RetroUI.text(button, "Day", "", px(196, 0), px(84, 34), { Size = 18, AlignX = RIGHT }),
			Hover = false,
		}
		rows[company.Ticker] = row
		RetroUI.hover(button, function(hot)
			row.Hover = hot
			paintRows()
		end)
		-- Like any list, a row selects the moment the mouse goes down; taps select on release so
		-- dragging the list on a touchscreen doesn't pick rows.
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and selected ~= company.Ticker then
				selectStock(company.Ticker)
			end
		end)
		button.Activated:Connect(function(input)
			if input and input.UserInputType == Enum.UserInputType.MouseButton1 then
				return
			end
			selectStock(company.Ticker)
		end)
	end
	function paintRows()
		for ticker, row in rows do
			local isSelected = ticker == selected
			row.Button.BackgroundTransparency = if isSelected then 0 elseif row.Hover then 0.8 else 1
			local now, base = price(ticker), open(ticker)
			row.Price.Text = Stocks.price(now)
			row.Day.Text = percent(now - base, base)
			for _, label in { row.Ticker, row.Price, row.Day } do
				RetroUI.setColor(label, if isSelected then C.Screen else C.Bright)
				label.TextStrokeTransparency = if isSelected then 1 else 0.88
			end
			if not isSelected and owned(ticker) > 0 then
				RetroUI.setColor(row.Ticker, C.Hot)
			end
		end
	end

	local detail = RetroUI.frame(marketPage, "Detail", px(316, 0), px(440, 432))
	local nameLabel = RetroUI.text(detail, "Name", "", px(0, 0), px(440, 24), { Font = RetroUI.Fonts.Title, Size = 18 })
	local metaLabel = RetroUI.text(detail, "Meta", "", px(0, 26), px(440, 18), { Size = 16, Color = C.Mid })
	local aboutLabel = RetroUI.text(detail, "About", "", px(0, 44), px(440, 18), { Size = 16, Color = C.Mid })
	local priceLabel = RetroUI.text(detail, "Price", "", px(0, 66), px(196, 40), { Size = 36, Color = C.Hot })
	local changeLabel = RetroUI.text(detail, "Change", "", px(196, 66), px(244, 40), { Size = 18, AlignX = RIGHT })
	local rangeButtons: { [string]: RetroUI.Button } = {}
	local drawChart: () -> ()
	for index, id in Stocks.RANGE_ORDER do
		rangeButtons[id] = RetroUI.button(
			detail,
			id,
			Stocks.RANGES[id].Label,
			px((index - 1) * 78, 112),
			px(70, 26),
			function()
				rangeId = id
				for other, button in rangeButtons do
					button:setSelected(other == id)
				end
				drawChart()
			end,
			{ Size = 16 }
		)
	end
	rangeButtons.Live:setSelected(true)
	local rangeLabel =
		RetroUI.text(detail, "RangeInfo", "", px(236, 112), px(204, 26), { Size = 16, AlignX = RIGHT, Color = C.Mid })
	local chart = RetroUI.chart(detail, "Chart", px(0, 144), Vector2.new(440, 140))
	local statsLabel = RetroUI.text(detail, "Stats", "", px(0, 292), px(440, 18), { Size = 16, Color = C.Mid })

	local function setQuantity(value: number)
		quantity = math.clamp(math.floor(value), 1, Stocks.MAX_ORDER)
	end
	local qtyBox: TextBox
	local refreshTrade: () -> ()
	local minus = RetroUI.button(detail, "Minus", "-", px(0, 316), px(36, 36), function()
		setQuantity(quantity - 1)
		refreshTrade()
	end, { Size = 24 })
	qtyBox = RetroUI.input(detail, "Quantity", px(42, 316), px(90, 36), "1")
	local plus = RetroUI.button(detail, "Plus", "+", px(138, 316), px(36, 36), function()
		setQuantity(quantity + 1)
		refreshTrade()
	end, { Size = 24 })
	local maxButton = RetroUI.button(detail, "Max", "MAX", px(180, 316), px(56, 36), function()
		setQuantity(math.max(1, Stocks.affordable(price(selected), state.Cash)))
		refreshTrade()
	end, { Size = 16 })
	local allButton = RetroUI.button(detail, "All", "ALL", px(242, 316), px(56, 36), function()
		setQuantity(math.max(1, owned(selected)))
		refreshTrade()
	end, { Size = 16 })
	local costLabel = RetroUI.text(detail, "Cost", "", px(306, 316), px(134, 36), {
		Size = 16,
		AlignX = RIGHT,
		Color = C.Mid,
		Wrap = true,
	})
	local place: (string) -> ()
	local buyButton = RetroUI.button(detail, "Buy", "BUY", px(0, 362), px(210, 40), function()
		place("Buy")
	end, { Font = RetroUI.Fonts.Title, Size = 18 })
	local sellButton = RetroUI.button(detail, "Sell", "SELL", px(230, 362), px(210, 40), function()
		place("Sell")
	end, { Font = RetroUI.Fonts.Title, Size = 18 })
	local messageLabel = RetroUI.text(detail, "Message", "", px(0, 410), px(440, 20), { Size = 16 })
	local _ = minus, plus, maxButton

	connect(qtyBox.FocusLost, function()
		local value = tonumber((qtyBox.Text:gsub("[^%d]", "")))
		setQuantity(value or quantity)
		refreshTrade()
	end)
	connect(qtyBox:GetPropertyChangedSignal("Text"), function()
		local digits = qtyBox.Text:gsub("[^%d]", ""):sub(1, 5)
		if digits ~= qtyBox.Text then
			qtyBox.Text = digits
		end
	end)

	function refreshTrade()
		if not qtyBox:IsFocused() then
			qtyBox.Text = tostring(quantity)
		end
		local now = price(selected)
		local cost, fee = Stocks.buyCost(now, quantity)
		local proceeds = Stocks.sellProceeds(now, quantity)
		costLabel.Text = string.format("BUY %s\nSELL %s", Stocks.money(cost), Stocks.money(proceeds))
		local have = owned(selected)
		buyButton:setEnabled(not pending and cost <= state.Cash and state.Loaded)
		sellButton:setEnabled(not pending and have >= quantity and state.Loaded)
		allButton:setEnabled(have > 0)
		buyButton:setText(if pending then "..." else "BUY")
		sellButton:setText(if pending then "..." else "SELL")
		-- Explain a disabled button unless a fresh order result is showing.
		if os.clock() < messageUntil then
			messageLabel.Text = message
			RetroUI.setColor(messageLabel, if messageGood then C.Hot else C.Bright)
		elseif not state.Loaded then
			messageLabel.Text = "CONNECTING TO THE EXCHANGE..."
			RetroUI.setColor(messageLabel, C.Mid)
		elseif cost > state.Cash then
			messageLabel.Text = string.format("YOU NEED %s MORE TO BUY %d.", Stocks.money(cost - state.Cash), quantity)
			RetroUI.setColor(messageLabel, C.Mid)
		else
			messageLabel.Text =
				string.format("INCLUDES A %s BROKER FEE (%.2f%%).", Stocks.money(fee), Stocks.FEE_RATE * 100)
			RetroUI.setColor(messageLabel, C.Mid)
		end
	end

	-- Chart history, per ticker and range: points oldest first and the tick of the last one.
	local history: { [string]: { Tick: number, Points: { number } } } = {}
	local loading: { [string]: boolean } = {}
	local function load(ticker: string, id: string)
		local key = ticker .. "/" .. id
		if loading[key] then
			return
		end
		loading[key] = true
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, "History", ticker, id)
			loading[key] = nil
			if not alive then
				return
			end
			if ok and type(result) == "table" and result.Ok and type(result.Points) == "table" then
				history[key] = { Tick = result.Tick, Points = result.Points }
				if ticker == selected and id == rangeId then
					drawChart()
				end
			else
				task.delay(1, function()
					if alive and ticker == selected and id == rangeId and not history[key] then
						load(ticker, id)
					end
				end)
			end
		end)
	end

	function drawChart()
		local entry = history[selected .. "/" .. rangeId]
		if not entry then
			chart:set({})
			rangeLabel.Text = ""
			load(selected, rangeId)
			return
		end
		local low, high = chart:set(entry.Points)
		local first, last = entry.Points[1], entry.Points[#entry.Points]
		if low and high then
			rangeLabel.Text =
				string.format("%s  H %s L %s", percent(last - first, first), Stocks.price(high), Stocks.price(low))
		end
	end

	local function paintDetail()
		local company = Stocks.byTicker[selected]
		local now, base = price(selected), open(selected)
		nameLabel.Text = string.upper(company.Name)
		metaLabel.Text = string.format("%s: %s  ·  %s", company.Exchange, company.Ticker, company.Sector)
		aboutLabel.Text = company.About
		priceLabel.Text = Stocks.price(now)
		changeLabel.Text = string.format("%+.2f (%s) TODAY", now - base, percent(now - base, base))
		local have = owned(selected)
		statsLabel.Text = string.format(
			"DIVIDEND %.2f%%/WK  ·  YOU OWN %d (%s)",
			company.Yield * 100,
			have,
			Stocks.money(have * now)
		)
	end

	function selectStock(ticker: string)
		selected = ticker
		paintRows()
		paintDetail()
		drawChart()
		refreshTrade()
	end

	render.Market = function()
		paintRows()
		paintDetail()
		drawChart()
		refreshTrade()
	end

	----------------------------------------------------------------------------------------------
	-- PORTFOLIO

	local portfolioPage = pages.Portfolio
	local summary: { [string]: TextLabel } = {}
	for index, spec in
		{
			{ "Value", "PORTFOLIO VALUE" },
			{ "Cash", "CASH" },
			{ "Profit", "PROFIT / LOSS" },
			{ "Weekly", "DIVIDEND / WEEK" },
		}
	do
		local box = RetroUI.frame(portfolioPage, spec[1], px(12 + (index - 1) * 189, 0), px(177, 70))
		RetroUI.border(box, C.Dim, 2)
		RetroUI.text(box, "Label", spec[2], px(10, 6), px(160, 18), { Size = 14, Color = C.Mid })
		summary[spec[1]] = RetroUI.text(box, "Value", "", px(10, 28), px(160, 34), { Size = 24, Color = C.Hot })
	end
	local heads = {
		{ "TICKER", 10, 90, LEFT },
		{ "SHARES", 100, 90, RIGHT },
		{ "PRICE", 200, 110, RIGHT },
		{ "VALUE", 320, 130, RIGHT },
		{ "PROFIT", 460, 150, RIGHT },
		{ "DIV/WK", 620, 112, RIGHT },
	}
	local tableFrame = RetroUI.frame(portfolioPage, "Holdings", px(12, 82), px(744, 350))
	RetroUI.border(tableFrame, C.Dim, 2)
	for _, head in heads do
		RetroUI.text(tableFrame, "Head", head[1], px(head[2], 0), px(head[3], 28), {
			Size = 16,
			Color = C.Mid,
			AlignX = head[4],
		})
	end
	RetroUI.rule(tableFrame, "HeadRule", px(0, 28), UDim.new(1, 0))
	local holdingsList = Instance.new("ScrollingFrame")
	holdingsList.Name = "Rows"
	holdingsList.BackgroundTransparency = 1
	holdingsList.BorderSizePixel = 0
	holdingsList.Position = px(0, 30)
	holdingsList.Size = UDim2.new(1, 0, 1, -30)
	holdingsList.ScrollBarThickness = 8
	holdingsList.ScrollBarImageColor3 = C.Mid
	holdingsList.Parent = tableFrame
	local emptyNote = RetroUI.text(
		tableFrame,
		"Empty",
		"YOU DON'T OWN ANY SHARES YET.\nPICK A COMPANY ON THE MARKET PAGE AND PRESS BUY.",
		px(20, 60),
		px(704, 80),
		{ AlignX = CENTER, Wrap = true, Size = 18, Color = C.Mid }
	)
	local openMarket = RetroUI.button(tableFrame, "OpenMarket", "OPEN MARKET", px(272, 160), px(200, 40), function()
		show("Market")
	end, { Font = RetroUI.Fonts.Title, Size = 16 })

	render.Portfolio = function()
		local now = prices()
		local value, cost, weekly = 0, 0, Stocks.estimate(state.Portfolio, now)
		local tickers = {}
		for ticker, holding in state.Portfolio.Holdings do
			table.insert(tickers, ticker)
			value += holding.Shares * now[ticker]
			cost += holding.Cost
		end
		table.sort(tickers, function(a, b)
			return Stocks.byTicker[a].Index < Stocks.byTicker[b].Index
		end)
		summary.Value.Text = Stocks.money(value)
		summary.Cash.Text = Stocks.money(state.Cash)
		local profit = value - cost
		summary.Profit.Text = (if profit < -0.5 then DOWN elseif profit > 0.5 then UP else "") .. signedMoney(profit)
		summary.Weekly.Text = Stocks.money(weekly)

		for _, child in holdingsList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		emptyNote.Visible = #tickers == 0
		openMarket.Instance.Visible = #tickers == 0
		holdingsList.CanvasSize = px(0, #tickers * 34)
		for index, ticker in tickers do
			local holding = state.Portfolio.Holdings[ticker]
			local worth = holding.Shares * now[ticker]
			local gain = worth - holding.Cost
			local row = Instance.new("TextButton")
			row.Name = ticker
			row.AutoButtonColor = false
			row.Text = ""
			row.BackgroundColor3 = C.Bright
			row.BackgroundTransparency = 1
			row.BorderSizePixel = 0
			row.Position = px(0, (index - 1) * 34)
			row.Size = UDim2.new(1, -10, 0, 34)
			row.Parent = holdingsList
			local cells = {
				ticker,
				tostring(holding.Shares),
				Stocks.price(now[ticker]),
				Stocks.money(worth),
				string.format("%s %s", signedMoney(gain), percent(gain, holding.Cost)),
				Stocks.money(holding.Shares * now[ticker] * Stocks.byTicker[ticker].Yield),
			}
			for column, head in heads do
				RetroUI.text(row, head[1], cells[column], px(head[2], 0), px(head[3], 34), {
					Size = if column == 5 then 16 else 20,
					AlignX = head[4],
				})
			end
			RetroUI.hover(row, function(hot)
				row.BackgroundTransparency = if hot then 0.8 else 1
			end)
			row.Activated:Connect(function()
				show("Market")
				selectStock(ticker)
			end)
		end
	end

	----------------------------------------------------------------------------------------------
	-- DIVIDENDS

	local dividendsPage = pages.Dividends
	local nextBox = RetroUI.frame(dividendsPage, "Next", px(12, 0), px(744, 118))
	RetroUI.border(nextBox, C.Bright, 2)
	RetroUI.text(nextBox, "Label", "NEXT PAYOUT IN", px(16, 10), px(400, 20), { Size = 16, Color = C.Mid })
	local countdown = RetroUI.text(nextBox, "Countdown", "", px(16, 34), px(400, 44), {
		Font = RetroUI.Fonts.Title,
		Size = 30,
		Color = C.Hot,
	})
	local realLabel = RetroUI.text(nextBox, "Real", "", px(16, 84), px(440, 20), { Size = 16, Color = C.Mid })
	RetroUI.text(nextBox, "EstimateLabel", "ESTIMATED PAYOUT", px(428, 10), px(300, 20), {
		Size = 16,
		Color = C.Mid,
		AlignX = RIGHT,
	})
	local estimate = RetroUI.text(nextBox, "Estimate", "", px(428, 34), px(300, 44), {
		Font = RetroUI.Fonts.Title,
		Size = 26,
		Color = C.Hot,
		AlignX = RIGHT,
	})
	local lifetime = RetroUI.text(nextBox, "Lifetime", "", px(428, 84), px(300, 20), {
		Size = 16,
		Color = C.Mid,
		AlignX = RIGHT,
	})
	RetroUI.text(
		dividendsPage,
		"Rules",
		string.format(
			"EVERY %d IN-GAME DAYS EACH COMPANY PAYS ITS WEEKLY DIVIDEND ON THE SHARES YOU HOLD AT THAT MOMENT. AWAY FROM THE HARBOUR? UP TO %d MISSED PAYOUTS ARE PAID WHEN YOU RETURN.",
			Stocks.WEEK_DAYS,
			Stocks.MAX_BACKPAY
		),
		px(12, 130),
		px(744, 66),
		{ Size = 16, Wrap = true, Color = C.Mid, AlignY = Enum.TextYAlignment.Top }
	)
	local paidFrame = RetroUI.frame(dividendsPage, "Paid", px(12, 206), px(744, 226))
	RetroUI.border(paidFrame, C.Dim, 2)
	RetroUI.text(paidFrame, "Head", "RECENT PAYOUTS", px(10, 0), px(300, 28), { Size = 16, Color = C.Mid })
	RetroUI.rule(paidFrame, "HeadRule", px(0, 28), UDim.new(1, 0))
	local paidRows = RetroUI.frame(paidFrame, "Rows", px(0, 30), UDim2.new(1, 0, 1, -30))

	local function paintCountdown()
		if page ~= "Dividends" then
			return
		end
		local elapsed = DayNight.elapsed()
		local nextAt = Stocks.weekStart(Stocks.weekAt(elapsed) + 1)
		countdown.Text = gameDuration(nextAt - elapsed)
		realLabel.Text = "ABOUT " .. string.upper(realDuration(nextAt - elapsed)) .. " OF REAL TIME"
	end

	render.Dividends = function()
		paintCountdown()
		estimate.Text = Stocks.money(Stocks.estimate(state.Portfolio, prices()))
		lifetime.Text = "LIFETIME " .. Stocks.money(state.Portfolio.Paid)
		for _, child in paidRows:GetChildren() do
			child:Destroy()
		end
		if #state.Portfolio.History == 0 then
			RetroUI.text(paidRows, "Empty", "NO PAYOUTS YET. BUY SHARES AND WAIT FOR PAYDAY.", px(10, 8), px(720, 28), {
				Size = 18,
				Color = C.Mid,
			})
		end
		local currentWeek = Stocks.weekAt(DayNight.elapsed())
		for index, entry in state.Portfolio.History do
			local ago = currentWeek - entry.Week
			local when = if ago <= 0
				then "THIS WEEK"
				elseif ago == 1 then "LAST WEEK"
				else string.format("%d WEEKS AGO", ago)
			local y = (index - 1) * 24 + 4
			if y + 24 <= 196 then
				RetroUI.text(paidRows, "When", when, px(10, y), px(300, 24), { Size = 18 })
				RetroUI.text(paidRows, "Amount", "+" .. Stocks.money(entry.Amount), px(434, y), px(300, 24), {
					Size = 18,
					AlignX = RIGHT,
					Color = C.Hot,
				})
			end
		end
	end

	----------------------------------------------------------------------------------------------
	-- Orders and refreshes

	local function applyState(view: any)
		if type(view) ~= "table" then
			return
		end
		state.Portfolio = Stocks.decode(view.Portfolio)
		if type(view.Cash) == "number" then
			state.Cash = view.Cash
		end
		state.NextPayout = view.NextPayout
		state.Loaded = true
		paintCash()
		render[page]()
	end

	local function refresh()
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, "Snapshot")
			if alive and ok and type(result) == "table" and result.Ok then
				applyState(result.State)
			end
		end)
	end

	function place(side: string)
		if pending or not state.Loaded then
			return
		end
		pending = true
		refreshTrade()
		local ticker, amount = selected, quantity
		onStatus(string.format("SENDING %s ORDER: %d %s...", string.upper(side), amount, ticker))
		task.spawn(function()
			local ok, result = pcall(remote.InvokeServer, remote, side, ticker, amount)
			pending = false
			if not alive then
				return
			end
			if ok and type(result) == "table" then
				message = string.upper(tostring(result.Message or ""))
				messageGood = result.Ok == true
				if not messageGood then
					message = "! " .. message
				end
				applyState(result.State)
			else
				message, messageGood = "! THE EXCHANGE DIDN'T ANSWER. TRY AGAIN.", false
			end
			messageUntil = os.clock() + 6
			onStatus(message)
			refreshTrade()
			task.delay(6.1, function()
				if alive then
					refreshTrade()
				end
			end)
		end)
	end

	connect(player:GetAttributeChangedSignal("Cash"), function()
		state.Cash = player:GetAttribute("Cash") or state.Cash
		paintCash()
		if page == "Market" then
			refreshTrade()
		else
			render[page]()
		end
	end)

	connect(market:GetAttributeChangedSignal("Tick"), function()
		local tick = market:GetAttribute("Tick")
		if type(tick) ~= "number" then
			return
		end
		-- Extend cached charts with the new price, or drop them when they fell behind.
		for key, entry in history do
			local ticker, id = string.match(key, "^(.-)/(.+)$")
			local range = Stocks.RANGES[id]
			if ticker and range then
				if id == "Live" and tick == entry.Tick + 1 then
					table.remove(entry.Points, 1)
					table.insert(entry.Points, price(ticker))
					entry.Tick = tick
				elseif id ~= "Live" and tick - entry.Tick < range.Step then
					entry.Points[#entry.Points] = price(ticker)
				elseif tick ~= entry.Tick then
					history[key] = nil
				end
			end
		end
		if page == "Market" then
			paintRows()
			paintDetail()
			drawChart()
			refreshTrade()
		else
			render[page]()
		end
	end)

	connect(market:GetAttributeChangedSignal("Week"), refresh)

	task.spawn(function()
		local sinceRefresh = 0
		while alive do
			task.wait(1)
			sinceRefresh += 1
			paintCountdown()
			if sinceRefresh >= 15 then
				sinceRefresh = 0
				refresh()
			end
		end
	end)

	paintCash()
	show("Market")
	refresh()
	return app
end

return StockApp
