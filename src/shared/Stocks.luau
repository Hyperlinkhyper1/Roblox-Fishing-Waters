-- The office PC's stock market (Harbour Exchange): the listed companies and the pure portfolio
-- rules the server runs inside UpdateAsync. Prices themselves are computed only on the server
-- (StockPrices, with a private salt) so nobody can read future prices out of this module.
--
-- Time is the shared in-game calendar (DayNight.elapsed): one in-game day is 24 real minutes,
-- so a dividend week is 7 in-game days = 168 real minutes.
local Stocks = {}

-- Real seconds between price ticks.
Stocks.TICK_SECONDS = 5
-- Real seconds in one in-game day (DayNight.SECONDS_PER_HOUR * 24).
Stocks.DAY_SECONDS = 24 * 60
Stocks.WEEK_DAYS = 7
Stocks.WEEK_SECONDS = Stocks.DAY_SECONDS * Stocks.WEEK_DAYS
-- In-game seconds per real second (an in-game minute passes every real second).
Stocks.GAME_SPEED = 60

-- Broker commission on every order.
Stocks.FEE_RATE = 0.0025
Stocks.MIN_FEE = 1
Stocks.MAX_ORDER = 10000
Stocks.MAX_SHARES = 1000000
-- Weeks that passed while you were away pay out at most this many times on your return.
Stocks.MAX_BACKPAY = 4
Stocks.HISTORY_LENGTH = 8

-- Chart ranges: how many ticks each covers and the spacing of the points sent for it.
Stocks.RANGES = {
	Live = { Ticks = 60, Step = 1, Label = "LIVE" },
	Day = { Ticks = 288, Step = 4, Label = "DAY" },
	Week = { Ticks = 2016, Step = 28, Label = "WEEK" },
}
Stocks.RANGE_ORDER = { "Live", "Day", "Week" }

-- Base is the price the stock swings around, Vol how far it swings (log scale), Yield the share
-- of its price paid as a dividend every in-game week. Prices are game prices, loosely real.
Stocks.Companies = {
	{
		Ticker = "AAPL",
		Name = "Apple Inc.",
		Exchange = "NASDAQ",
		Sector = "Technology",
		About = "iPhones, Macs and services",
		Base = 230,
		Vol = 0.22,
		Yield = 0.004,
	},
	{
		Ticker = "MSFT",
		Name = "Microsoft",
		Exchange = "NASDAQ",
		Sector = "Technology",
		About = "Windows, Office and Azure cloud",
		Base = 420,
		Vol = 0.2,
		Yield = 0.005,
	},
	{
		Ticker = "NVDA",
		Name = "NVIDIA",
		Exchange = "NASDAQ",
		Sector = "Semiconductors",
		About = "Graphics chips and AI accelerators",
		Base = 180,
		Vol = 0.38,
		Yield = 0.002,
	},
	{
		Ticker = "AMZN",
		Name = "Amazon.com",
		Exchange = "NASDAQ",
		Sector = "Retail & cloud",
		About = "Online store and AWS",
		Base = 200,
		Vol = 0.28,
		Yield = 0.002,
	},
	{
		Ticker = "TSLA",
		Name = "Tesla",
		Exchange = "NASDAQ",
		Sector = "Automotive",
		About = "Electric cars and batteries",
		Base = 250,
		Vol = 0.45,
		Yield = 0.001,
	},
	{
		Ticker = "RBLX",
		Name = "Roblox Corp.",
		Exchange = "NYSE",
		Sector = "Gaming",
		About = "The platform you are playing on",
		Base = 60,
		Vol = 0.42,
		Yield = 0.002,
	},
	{
		Ticker = "JPM",
		Name = "JPMorgan Chase",
		Exchange = "NYSE",
		Sector = "Banking",
		About = "America's largest bank",
		Base = 240,
		Vol = 0.18,
		Yield = 0.009,
	},
	{
		Ticker = "KO",
		Name = "Coca-Cola",
		Exchange = "NYSE",
		Sector = "Beverages",
		About = "Soft drinks sold everywhere",
		Base = 68,
		Vol = 0.1,
		Yield = 0.012,
	},
	{
		Ticker = "MCD",
		Name = "McDonald's",
		Exchange = "NYSE",
		Sector = "Restaurants",
		About = "Burgers, fries and franchises",
		Base = 290,
		Vol = 0.12,
		Yield = 0.01,
	},
	{
		Ticker = "DIS",
		Name = "Walt Disney",
		Exchange = "NYSE",
		Sector = "Entertainment",
		About = "Films, parks and cruise ships",
		Base = 110,
		Vol = 0.24,
		Yield = 0.006,
	},
	{
		Ticker = "SHEL",
		Name = "Shell plc",
		Exchange = "NYSE",
		Sector = "Energy",
		About = "Oil, gas and marine fuel",
		Base = 70,
		Vol = 0.22,
		Yield = 0.014,
	},
	{
		Ticker = "CCL",
		Name = "Carnival Corp.",
		Exchange = "NYSE",
		Sector = "Cruise lines",
		About = "Cruise ships, like the ones in the city port",
		Base = 24,
		Vol = 0.4,
		Yield = 0.005,
	},
	{
		Ticker = "BC",
		Name = "Brunswick",
		Exchange = "NYSE",
		Sector = "Boats & engines",
		About = "Mercury outboards, Sea Ray and Boston Whaler",
		Base = 65,
		Vol = 0.3,
		Yield = 0.008,
	},
	{
		Ticker = "AMKBY",
		Name = "A.P. Moller-Maersk",
		Exchange = "OTC",
		Sector = "Shipping",
		About = "Container ships and ports",
		Base = 9,
		Vol = 0.32,
		Yield = 0.016,
	},
	{
		Ticker = "MHGVY",
		Name = "Mowi ASA",
		Exchange = "OTC",
		Sector = "Seafood",
		About = "The world's biggest salmon farmer",
		Base = 18,
		Vol = 0.2,
		Yield = 0.018,
	},
	{
		Ticker = "SMNNY",
		Name = "Shimano",
		Exchange = "OTC",
		Sector = "Fishing & cycling",
		About = "Fishing reels, rods and bike parts",
		Base = 14,
		Vol = 0.24,
		Yield = 0.007,
	},
}

Stocks.byTicker = {}
for index, company in Stocks.Companies do
	company.Index = index
	Stocks.byTicker[company.Ticker] = company
end

function Stocks.tickAt(elapsed: number): number
	return math.floor(elapsed / Stocks.TICK_SECONDS)
end

function Stocks.dayAt(elapsed: number): number
	return math.floor(elapsed / Stocks.DAY_SECONDS)
end

-- The dividend week `elapsed` falls in. Week n pays out at its start, weekStart(n).
function Stocks.weekAt(elapsed: number): number
	return math.floor(elapsed / Stocks.WEEK_SECONDS)
end

function Stocks.weekStart(week: number): number
	return week * Stocks.WEEK_SECONDS
end

-- First tick of the in-game day `elapsed` falls in (the day's opening price).
function Stocks.dayOpenTick(elapsed: number): number
	return math.ceil(Stocks.dayAt(elapsed) * Stocks.DAY_SECONDS / Stocks.TICK_SECONDS)
end

function Stocks.weekTick(week: number): number
	return math.ceil(Stocks.weekStart(week) / Stocks.TICK_SECONDS)
end

function Stocks.fee(amount: number): number
	return math.max(Stocks.MIN_FEE, math.ceil(amount * Stocks.FEE_RATE))
end

function Stocks.buyCost(price: number, shares: number): (number, number)
	local gross = math.ceil(price * shares - 1e-9)
	local fee = Stocks.fee(gross)
	return gross + fee, fee
end

function Stocks.sellProceeds(price: number, shares: number): (number, number)
	local gross = math.floor(price * shares + 1e-9)
	local fee = math.min(gross, Stocks.fee(gross))
	return gross - fee, fee
end

-- Most whole shares `cash` buys at `price`, fee included.
function Stocks.affordable(price: number, cash: number): number
	if price <= 0 then
		return 0
	end
	local shares = math.min(Stocks.MAX_ORDER, math.floor(cash / (price * (1 + Stocks.FEE_RATE))))
	while shares > 0 and Stocks.buyCost(price, shares) > cash do
		shares -= 1
	end
	return math.max(shares, 0)
end

local function wholeNumber(value: any, max: number): boolean
	return type(value) == "number" and value >= 0 and value <= max and value % 1 == 0
end

-- A saved portfolio, normalized. Unknown tickers and malformed entries are dropped rather than
-- failing the profile, the same as retired rod skins.
export type Portfolio = {
	Holdings: { [string]: { Shares: number, Cost: number } },
	Week: number?,
	Paid: number,
	History: { { Week: number, Amount: number } },
}

function Stocks.decode(raw: any): Portfolio
	local portfolio: Portfolio = { Holdings = {}, Week = nil, Paid = 0, History = {} }
	if type(raw) ~= "table" then
		return portfolio
	end
	if type(raw.Holdings) == "table" then
		for ticker, holding in raw.Holdings do
			if
				type(ticker) == "string"
				and Stocks.byTicker[ticker]
				and type(holding) == "table"
				and wholeNumber(holding.Shares, Stocks.MAX_SHARES)
				and holding.Shares > 0
				and wholeNumber(holding.Cost, 2 ^ 53 - 1)
			then
				portfolio.Holdings[ticker] = { Shares = holding.Shares, Cost = holding.Cost }
			end
		end
	end
	if wholeNumber(raw.Week, 2 ^ 31) then
		portfolio.Week = raw.Week
	end
	if wholeNumber(raw.Paid, 2 ^ 53 - 1) then
		portfolio.Paid = raw.Paid
	end
	if type(raw.History) == "table" then
		for _, entry in raw.History do
			if
				type(entry) == "table"
				and wholeNumber(entry.Week, 2 ^ 31)
				and wholeNumber(entry.Amount, 2 ^ 53 - 1)
				and #portfolio.History < Stocks.HISTORY_LENGTH
			then
				table.insert(portfolio.History, { Week = entry.Week, Amount = entry.Amount })
			end
		end
	end
	return portfolio
end

function Stocks.hasHoldings(portfolio: Portfolio): boolean
	return next(portfolio.Holdings) ~= nil
end

-- Pays every dividend week that started since the portfolio was last settled, at the shares held
-- now (trades always settle first, so those were the shares held at each payout). `priceAt(ticker,
-- week)` is the price at that week's opening tick. Returns the cash earned and the weeks paid.
function Stocks.settle(portfolio: Portfolio, week: number, priceAt: (string, number) -> number): (number, number)
	local last = portfolio.Week
	portfolio.Week = math.max(last or week, week)
	if last == nil or week <= last or not Stocks.hasHoldings(portfolio) then
		return 0, 0
	end
	local first = math.max(last + 1, week - Stocks.MAX_BACKPAY + 1)
	local total = 0
	for payWeek = first, week do
		local amount = 0
		for ticker, holding in portfolio.Holdings do
			amount += holding.Shares * priceAt(ticker, payWeek) * Stocks.byTicker[ticker].Yield
		end
		amount = math.floor(amount)
		if amount > 0 then
			table.insert(portfolio.History, 1, { Week = payWeek, Amount = amount })
			total += amount
		end
	end
	while #portfolio.History > Stocks.HISTORY_LENGTH do
		table.remove(portfolio.History)
	end
	portfolio.Paid += total
	return total, week - first + 1
end

-- What a week's payout would be at `prices` (ticker -> price), for the app's estimate.
function Stocks.estimate(portfolio: Portfolio, prices: { [string]: number }): number
	local amount = 0
	for ticker, holding in portfolio.Holdings do
		amount += holding.Shares * (prices[ticker] or 0) * Stocks.byTicker[ticker].Yield
	end
	return math.floor(amount)
end

-- Buys `shares` whole shares. Returns the result code, the new cash and the cost paid.
function Stocks.buy(
	portfolio: Portfolio,
	cash: number,
	ticker: string,
	price: number,
	shares: number
): (string, number, number)
	if not Stocks.byTicker[ticker] then
		return "UnknownStock", cash, 0
	elseif type(shares) ~= "number" or shares % 1 ~= 0 or shares < 1 or shares > Stocks.MAX_ORDER then
		return "InvalidAmount", cash, 0
	end
	local holding = portfolio.Holdings[ticker]
	if (holding and holding.Shares or 0) + shares > Stocks.MAX_SHARES then
		return "TooMany", cash, 0
	end
	local cost = Stocks.buyCost(price, shares)
	if cost > cash then
		return "InsufficientFunds", cash, cost
	end
	if holding then
		holding.Shares += shares
		holding.Cost += cost
	else
		portfolio.Holdings[ticker] = { Shares = shares, Cost = cost }
	end
	return "Bought", cash - cost, cost
end

-- Sells `shares` shares. The cost basis shrinks in proportion. Returns code, new cash, proceeds.
function Stocks.sell(
	portfolio: Portfolio,
	cash: number,
	ticker: string,
	price: number,
	shares: number
): (string, number, number)
	local holding = portfolio.Holdings[ticker]
	if not Stocks.byTicker[ticker] then
		return "UnknownStock", cash, 0
	elseif type(shares) ~= "number" or shares % 1 ~= 0 or shares < 1 then
		return "InvalidAmount", cash, 0
	elseif not holding or holding.Shares < shares then
		return "NotEnoughShares", cash, 0
	end
	local proceeds = Stocks.sellProceeds(price, shares)
	if shares == holding.Shares then
		portfolio.Holdings[ticker] = nil
	else
		holding.Cost -= math.floor(holding.Cost * shares / holding.Shares)
		holding.Shares -= shares
	end
	return "Sold", cash + proceeds, proceeds
end

function Stocks.money(amount: number): string
	local negative = amount < 0
	local whole = math.floor(math.abs(amount) + 0.5)
	local text = tostring(whole):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if text:sub(1, 1) == "," then
		text = text:sub(2)
	end
	return (if negative then "-$" else "$") .. text
end

function Stocks.price(amount: number): string
	if amount >= 1000 then
		return Stocks.money(amount)
	end
	return string.format("$%.2f", amount)
end

return Stocks
