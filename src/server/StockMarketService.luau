-- Harbour Exchange, the investment app on the office PC. Prices tick every Stocks.TICK_SECONDS
-- (StockPrices, the same on every server) and replicate as attributes on
-- ReplicatedStorage.StockMarket: P_<ticker> is the price now, O_<ticker> the in-game day's open.
-- Trades are only accepted from a player sitting at their own office PC. Holdings are saved on
-- the profile as `Portfolio` (Shared.Stocks.decode) and pay a dividend every 7 in-game days.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatService = require(script.Parent.BoatService)
local OfficeComputerService = require(script.Parent.OfficeComputerService)
local StockPrices = require(script.Parent.StockPrices)
local DayNight = require(ReplicatedStorage.Shared.DayNight)
local Stocks = require(ReplicatedStorage.Shared.Stocks)

local Service = {}
local started = false

-- How often online portfolios are checked for a dividend week that has started.
local PAYOUT_CHECK_SECONDS = 15

local folder: Folder
local busy: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}

local function now(): number
	return DayNight.elapsed()
end

local function currentTick(): number
	return Stocks.tickAt(now())
end

local function notify(player: Player, message: string)
	local boating = ReplicatedStorage:FindFirstChild("Boating")
	local feedback = boating and boating:FindFirstChild("Feedback")
	if feedback and feedback:IsA("RemoteEvent") and player.Parent == Players then
		feedback:FireClient(player, "Notice", message)
	end
end

local function publishPrices()
	local elapsed = now()
	local tick = Stocks.tickAt(elapsed)
	local open = Stocks.dayOpenTick(elapsed)
	for _, company in Stocks.Companies do
		folder:SetAttribute("P_" .. company.Ticker, StockPrices.price(company.Ticker, tick))
		folder:SetAttribute("O_" .. company.Ticker, StockPrices.price(company.Ticker, open))
	end
	folder:SetAttribute("Tick", tick)
	folder:SetAttribute("Week", Stocks.weekAt(elapsed))
end

local function view(player: Player, profile: any?)
	profile = profile or BoatService.getProfile(player)
	if not profile then
		return nil
	end
	local elapsed = now()
	local week = Stocks.weekAt(elapsed)
	return {
		Portfolio = Stocks.decode(profile.Portfolio),
		Cash = profile.Cash,
		Elapsed = elapsed,
		Week = week,
		NextPayout = Stocks.weekStart(week + 1),
	}
end

-- Settles dividends and applies `trade` (if any) in one save. Returns ok, message, earned.
local function transact(player: Player, trade: ((any, any) -> (string, number))?): (boolean, string, number)
	local week = Stocks.weekAt(now())
	local earned, result = 0, nil
	local ok, message = BoatService.updateProgress(player, function(current)
		local portfolio = Stocks.decode(current.Portfolio)
		earned = Stocks.settle(portfolio, week, StockPrices.weekPrice)
		current.Cash += earned
		if trade then
			local code, cash = trade(portfolio, current.Cash)
			result = code
			if code == "Bought" or code == "Sold" then
				current.Cash = cash
			end
		end
		current.Portfolio = portfolio
	end)
	if not ok then
		return false, message, 0
	end
	if earned > 0 then
		notify(player, "Harbour Exchange paid you " .. Stocks.money(earned) .. " in dividends!")
	end
	return true, result or "Settled", earned
end

local function order(player: Player, side: string, ticker: any, shares: any): (boolean, string)
	local company = type(ticker) == "string" and Stocks.byTicker[ticker]
	if not company then
		return false, "That stock isn't listed."
	end
	if type(shares) ~= "number" or shares % 1 ~= 0 or shares < 1 or shares > Stocks.MAX_ORDER then
		return false, string.format("Enter between 1 and %d shares.", Stocks.MAX_ORDER)
	end
	local price = StockPrices.price(ticker, currentTick())
	local amount = 0
	local ok, code = transact(player, function(portfolio, cash)
		local result, newCash, total
		if side == "Buy" then
			result, newCash, total = Stocks.buy(portfolio, cash, ticker, price, shares)
		else
			result, newCash, total = Stocks.sell(portfolio, cash, ticker, price, shares)
		end
		amount = total
		return result, newCash
	end)
	if not ok then
		return false, code
	end
	local plural = if shares == 1 then "share" else "shares"
	if code == "Bought" then
		return true,
			string.format(
				"Bought %d %s %s at %s for %s.",
				shares,
				ticker,
				plural,
				Stocks.price(price),
				Stocks.money(amount)
			)
	elseif code == "Sold" then
		return true,
			string.format(
				"Sold %d %s %s at %s for %s.",
				shares,
				ticker,
				plural,
				Stocks.price(price),
				Stocks.money(amount)
			)
	elseif code == "InsufficientFunds" then
		return false, "Not enough cash: that order costs " .. Stocks.money(amount) .. "."
	elseif code == "NotEnoughShares" then
		return false, "You don't own that many " .. ticker .. " shares."
	elseif code == "TooMany" then
		return false, "That would be more shares than the exchange allows one investor."
	end
	return false, "That order couldn't be placed."
end

local function payOnline()
	local week = Stocks.weekAt(now())
	for _, player in Players:GetPlayers() do
		if not busy[player] then
			local profile = BoatService.getProfile(player)
			local portfolio = profile and Stocks.decode(profile.Portfolio)
			if portfolio and Stocks.hasHoldings(portfolio) and (portfolio.Week or week) < week then
				busy[player] = true
				task.spawn(function()
					local ok, problem = pcall(transact, player, nil)
					if not ok then
						warn("[StockMarket] Dividend payout failed: " .. tostring(problem))
					end
					busy[player] = nil
				end)
			end
		end
	end
end

function Service.start()
	if started then
		return
	end
	started = true
	folder = Instance.new("Folder")
	folder.Name = "StockMarket"
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Request"
	remote.Parent = folder
	publishPrices()
	folder.Parent = ReplicatedStorage

	remote.OnServerInvoke = function(player, action, ticker, value)
		if action == "Snapshot" then
			return { Ok = true, State = view(player) }
		elseif action == "History" then
			if
				type(ticker) ~= "string"
				or not Stocks.byTicker[ticker]
				or type(value) ~= "string"
				or not Stocks.RANGES[value]
			then
				return { Ok = false }
			end
			if os.clock() - (lastRequest[player] or -math.huge) < 0.1 then
				return { Ok = false }
			end
			lastRequest[player] = os.clock()
			local tick = currentTick()
			return { Ok = true, Tick = tick, Points = StockPrices.history(ticker, value, tick) }
		end
		if action ~= "Buy" and action ~= "Sell" then
			return { Ok = false, Message = "Unknown request." }
		end
		if busy[player] or os.clock() - (lastRequest[player] or -math.huge) < 0.3 then
			return { Ok = false, Message = "One moment...", State = view(player) }
		end
		if not OfficeComputerService.atDesk(player) then
			return { Ok = false, Message = "Sit at your office computer to trade.", State = view(player) }
		end
		lastRequest[player] = os.clock()
		busy[player] = true
		local ok, success, message = pcall(order, player, action, ticker, value)
		busy[player] = nil
		if not ok then
			warn("[StockMarket] " .. tostring(success))
			return { Ok = false, Message = "The exchange is busy. Try again in a moment.", State = view(player) }
		end
		return { Ok = success, Message = message, State = view(player) }
	end

	Players.PlayerRemoving:Connect(function(player)
		busy[player], lastRequest[player] = nil, nil
	end)

	task.spawn(function()
		local sinceCheck = 0
		while true do
			local elapsed = now()
			-- Wake on the next tick boundary so every server ticks together.
			local wait = Stocks.TICK_SECONDS - (elapsed % Stocks.TICK_SECONDS)
			sinceCheck += task.wait(math.max(wait, 0.05))
			publishPrices()
			if sinceCheck >= PAYOUT_CHECK_SECONDS then
				sinceCheck = 0
				payOnline()
			end
		end
	end)
end

return Service
