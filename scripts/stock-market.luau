-- Rules for the office PC's stock market: lute run scripts/stock-market.luau
-- Covers Shared.Stocks (orders, fees, dividend settlement, portfolio decoding) and the server's
-- StockPrices engine (deterministic, sensible swings at every chart range).
local Stocks = require("../src/shared/Stocks")
local StockPrices = require("../src/server/StockPrices")

local failures = 0
local function check(condition: any, message: string)
	if not condition then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- Catalogue
local seen = {}
for _, company in Stocks.Companies do
	check(not seen[company.Ticker], "Duplicate ticker " .. company.Ticker)
	seen[company.Ticker] = true
	check(#company.Ticker <= 6, company.Ticker .. " ticker is too long for the list")
	check(company.Base > 0 and company.Vol > 0 and company.Vol < 0.6, company.Ticker .. " has odd price settings")
	check(company.Yield > 0 and company.Yield < 0.03, company.Ticker .. " weekly yield is out of range")
	check(#company.Name <= 22, company.Ticker .. " name is too long for the detail header")
end
check(#Stocks.Companies >= 12, "The exchange lists at least a dozen companies")

-- Prices: deterministic, positive, moving at every range, staying near their base.
local now = Stocks.tickAt(1792000000 - 1767225600)
for _, company in Stocks.Companies do
	local ticker = company.Ticker
	check(StockPrices.price(ticker, now) == StockPrices.price(ticker, now), ticker .. " price is not deterministic")
	local function spread(ticks: number, step: number): (number, number)
		local low, high = math.huge, -math.huge
		for index = 0, ticks, step do
			local value = StockPrices.price(ticker, now - index)
			check(value > 0, ticker .. " price fell to zero")
			low, high = math.min(low, value), math.max(high, value)
		end
		return low, high
	end
	local liveLow, liveHigh = spread(60, 1)
	check(liveHigh > liveLow, ticker .. " does not move over five minutes")
	check(liveHigh / liveLow < 1.35, ticker .. " swings too wildly over five minutes")
	local yearLow, yearHigh = spread(105120, 97)
	check(yearLow > company.Base * 0.12 and yearHigh < company.Base * 8, ticker .. " drifts too far from its base")
	local week = StockPrices.history(ticker, "Week", now)
	check(#week == 73, ticker .. " week chart has the wrong number of points")
	check(week[#week] == StockPrices.price(ticker, now), ticker .. " week chart does not end at the live price")
	check(#StockPrices.history(ticker, "Live", now) == 61, ticker .. " live chart has the wrong number of points")
end
check(StockPrices.price("AAPL", now) ~= StockPrices.price("MSFT", now) / 420 * 230, "Stocks share one random walk")

-- Fees and order sizes.
check(Stocks.fee(10) == 1, "Small orders pay the minimum fee")
check(Stocks.fee(10000) == 25, "Fee is 0.25%")
local cost, fee = Stocks.buyCost(12.34, 10)
check(cost == 124 + 1 and fee == 1, "Buy cost rounds the gross up and adds the fee")
check(Stocks.sellProceeds(12.34, 10) == 123 - 1, "Sale rounds the gross down and takes the fee")
check(Stocks.affordable(100, 1000) == 9, "Affordable leaves room for the fee")
check(Stocks.buyCost(100, Stocks.affordable(100, 1000)) <= 1000, "Affordable order fits the cash")
check(Stocks.affordable(100, 50) == 0, "Can't afford a single share")

-- Buying, selling and the cost basis.
local portfolio = Stocks.decode(nil)
local code, cash = Stocks.buy(portfolio, 1000, "KO", 68, 5)
check(code == "Bought" and cash == 1000 - 341, "Buying 5 KO at $68 costs $341 with the fee")
check(portfolio.Holdings.KO.Shares == 5 and portfolio.Holdings.KO.Cost == 341, "Holding records shares and cost")
code = Stocks.buy(portfolio, 10, "KO", 68, 1)
check(code == "InsufficientFunds", "Can't buy without the cash")
code = Stocks.buy(portfolio, 1000, "NOPE", 1, 1)
check(code == "UnknownStock", "Unknown tickers are refused")
code = Stocks.buy(portfolio, 1000, "KO", 68, 1.5)
check(code == "InvalidAmount", "Fractional shares are refused")
code = Stocks.buy(portfolio, 1e12, "KO", 1, Stocks.MAX_ORDER + 1)
check(code == "InvalidAmount", "Orders are capped")
code, cash = Stocks.sell(portfolio, 0, "KO", 70, 2)
check(code == "Sold" and cash == 139, "Selling 2 KO at $70 pays $139 after the fee")
check(portfolio.Holdings.KO.Shares == 3 and portfolio.Holdings.KO.Cost == 341 - 136, "Selling shrinks the cost basis")
code = Stocks.sell(portfolio, 0, "KO", 70, 4)
check(code == "NotEnoughShares", "Can't sell more than you own")
code = Stocks.sell(portfolio, 0, "KO", 70, 3)
check(code == "Sold" and portfolio.Holdings.KO == nil, "Selling everything removes the holding")

-- Dividends.
local function flat(price: number)
	return function(_ticker: string, _week: number): number
		return price
	end
end
portfolio = Stocks.decode(nil)
local earned, weeks = Stocks.settle(portfolio, 100, flat(100))
check(earned == 0 and weeks == 0 and portfolio.Week == 100, "A new portfolio starts at the current week")
Stocks.buy(portfolio, 1e6, "KO", 100, 100)
earned = Stocks.settle(portfolio, 100, flat(100))
check(earned == 0, "Nothing is paid again within the same week")
earned, weeks = Stocks.settle(portfolio, 101, flat(100))
check(earned == 120 and weeks == 1, "One week of KO pays 1.2% of the holding's value")
check(portfolio.Paid == 120 and portfolio.History[1].Week == 101, "Payouts are recorded")
earned, weeks = Stocks.settle(portfolio, 120, flat(100))
check(weeks == Stocks.MAX_BACKPAY and earned == 120 * Stocks.MAX_BACKPAY, "Back pay after a long absence is capped")
check(portfolio.Week == 120, "Settling moves to the current week")
earned = Stocks.settle(portfolio, 110, flat(100))
check(earned == 0 and portfolio.Week == 120, "A calendar moved backwards pays nothing and keeps the week")
for week = 121, 140 do
	Stocks.settle(portfolio, week, flat(100))
end
check(#portfolio.History == Stocks.HISTORY_LENGTH, "Payout history is trimmed")
check(Stocks.estimate(portfolio, { KO = 100 }) == 120, "Estimate matches a payout")

-- Decoding drops what it can't trust.
local decoded = Stocks.decode({
	Holdings = {
		KO = { Shares = 3, Cost = 200 },
		NOPE = { Shares = 1, Cost = 1 },
		MSFT = { Shares = -1, Cost = 1 },
		AAPL = { Shares = 1.5, Cost = 1 },
	},
	Week = 7,
	Paid = 30,
	History = { { Week = 7, Amount = 30 }, { Week = "x", Amount = 1 } },
})
check(decoded.Holdings.KO and decoded.Holdings.KO.Shares == 3, "Valid holdings survive decoding")
check(not decoded.Holdings.NOPE and not decoded.Holdings.MSFT and not decoded.Holdings.AAPL, "Bad holdings are dropped")
check(decoded.Week == 7 and decoded.Paid == 30 and #decoded.History == 1, "Week, total and history decode")
check(next(Stocks.decode("garbage").Holdings) == nil, "Garbage decodes to an empty portfolio")

-- Formatting.
check(Stocks.money(1234567) == "$1,234,567", "Money groups thousands")
check(Stocks.money(-50) == "-$50", "Negative money")
check(Stocks.money(999) == "$999", "Money under a thousand")
check(Stocks.price(12.5) == "$12.50", "Prices show cents")

-- Week/day helpers line up with the calendar.
check(Stocks.WEEK_SECONDS == 7 * 24 * 60, "A dividend week is 7 in-game days")
check(Stocks.weekAt(Stocks.weekStart(5)) == 5 and Stocks.weekAt(Stocks.weekStart(5) - 1) == 4, "Week boundaries")
check(Stocks.dayOpenTick(Stocks.DAY_SECONDS * 3 + 100) * Stocks.TICK_SECONDS == Stocks.DAY_SECONDS * 3, "Day open tick")

if failures > 0 then
	error(string.format("%d stock market check(s) failed", failures))
end
print("Stock market checks passed")
