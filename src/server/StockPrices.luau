-- Share prices for the office PC's stock market. Each price is a pure function of the tick, so
-- every server shows the same market without saving anything, and history can be redrawn for any
-- range. Octaves of smooth value noise (short wiggles to slow cycles) move the log price around
-- each company's base price. Lives on the server only: the salt keeps future prices private.
local Stocks = if script
	then require(game:GetService("ReplicatedStorage").Shared.Stocks)
	else require("../shared/Stocks")

local StockPrices = {}

local SALT = 0x5f3a91c7
-- Noise periods in ticks (5 s): from a few seconds to about a quarter of an in-game year.
local PERIODS = { 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049 }
-- Amplitude grows with period^0.32: live moves of a few percent, slow swings of about 2x.
local AMPLITUDES = {}
do
	local norm = 0
	for index, period in PERIODS do
		AMPLITUDES[index] = period ^ 0.32
		norm += AMPLITUDES[index] ^ 2
	end
	norm = math.sqrt(norm)
	for index in PERIODS do
		AMPLITUDES[index] /= norm
	end
end

local TWO32 = 4294967296

-- 32-bit multiply without losing bits in doubles.
local function mul32(a: number, b: number): number
	local lo = a % 65536
	local hi = (a - lo) / 65536
	return ((hi * b) % 65536 * 65536 + lo * b) % TWO32
end

local function mix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85ebca6b)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xc2b2ae35)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

-- Uniform in [-1, 1] for one noise lattice cell.
local function lattice(seed: number, octave: number, cell: number): number
	local h = mix(bit32.bxor(seed, mul32(octave + 1, 0x9e3779b9)))
	h = mix(bit32.bxor(h, cell % TWO32))
	h = mix(bit32.bxor(h, math.floor(cell / TWO32) % TWO32))
	return h / TWO32 * 2 - 1
end

local seeds: { [string]: number } = {}
local function seedFor(ticker: string): number
	local seed = seeds[ticker]
	if not seed then
		seed = SALT
		for index = 1, #ticker do
			seed = mix(bit32.bxor(seed, mul32(string.byte(ticker, index), 0x01000193)))
		end
		seeds[ticker] = seed
	end
	return seed
end

-- Smooth noise sum in about [-3, 3], standard deviation near 1.
function StockPrices.noise(ticker: string, tick: number): number
	local seed = seedFor(ticker)
	local total = 0
	for index, period in PERIODS do
		local x = tick / period
		local cell = math.floor(x)
		local t = x - cell
		t = t * t * (3 - 2 * t)
		local a, b = lattice(seed, index, cell), lattice(seed, index, cell + 1)
		total += (a + (b - a) * t) * AMPLITUDES[index]
	end
	return total
end

-- Price in cents-rounded dollars at a tick.
function StockPrices.price(ticker: string, tick: number): number
	local company = Stocks.byTicker[ticker]
	assert(company, "Unknown stock " .. tostring(ticker))
	local value = company.Base * math.exp(StockPrices.noise(ticker, tick) * company.Vol)
	return math.max(0.01, math.floor(value * 100 + 0.5) / 100)
end

-- Price when dividend week `week` opened.
function StockPrices.weekPrice(ticker: string, week: number): number
	return StockPrices.price(ticker, Stocks.weekTick(week))
end

-- Chart points for a range ending at `tick`, oldest first.
function StockPrices.history(ticker: string, rangeId: string, tick: number): { number }
	local range = Stocks.RANGES[rangeId]
	assert(range, "Unknown chart range")
	local points = {}
	local count = math.floor(range.Ticks / range.Step)
	for index = count, 0, -1 do
		table.insert(points, StockPrices.price(ticker, tick - index * range.Step))
	end
	return points
end

return StockPrices
