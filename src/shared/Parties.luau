-- The parties, what each one's government does for every angler, and the election calendar.
-- Pure rules shared by ElectionService, the ballot, the chamber's crowd and the hall's boards.
--
-- A term lasts four in-game years (about 24 real days, see Calendar). Polls are open from
-- 1 September of the term's last year until the year ends; the party with the most votes
-- across every server governs the whole next term, and its policy applies to everyone.
local Calendar = require(script.Parent.Calendar)

local Parties = {}
local rgb = Color3.fromRGB

Parties.TERM_YEARS = 4
Parties.POLLS_OPEN = { Month = 9, Day = 1 }
Parties.SEATS = 150

-- `Policy` is published on ReplicatedStorage as the Policy<Kind> attribute while the party
-- governs; gameplay reads that number (0 when nobody governs that policy).
--   XP         share of extra XP on every landed catch
--   FishPrice  share added to fish sold over a shop counter
--   DishPrice  share added to dishes sold in shops and restaurants
--   Luck       added to every cast's luck (rarer fish)
--   Size       added to the size boost (heavier fish)
--   Reel       added to reel power and handling (easier fights)
Parties.List = {
	{
		Id = "VB",
		Name = "Anglers' Union",
		Leader = "Jannes Kotter",
		Color = rgb(31, 97, 168),
		Slogan = "Skill pays.",
		Policy = { Kind = "XP", Amount = 0.15, Name = "Craftsmanship Act", Text = "+15% XP for every catch" },
	},
	{
		Id = "VK",
		Name = "Free Traders",
		Leader = "Mirthe van Loon",
		Color = rgb(226, 142, 38),
		Slogan = "Open markets, full tills.",
		Policy = { Kind = "FishPrice", Amount = 0.1, Name = "Free Trade Deal", Text = "+10% on fish sold in your shop" },
	},
	{
		Id = "PvdS",
		Name = "Good Food Party",
		Leader = "Okke Brandsma",
		Color = rgb(176, 48, 58),
		Slogan = "Honest food for everyone.",
		Policy = { Kind = "DishPrice", Amount = 0.12, Name = "Kitchen Subsidy", Text = "+12% on every dish you sell" },
	},
	{
		Id = "GG",
		Name = "Green Wave",
		Leader = "Fenna Zeilstra",
		Color = rgb(58, 148, 92),
		Slogan = "A clean sea gives more.",
		Policy = { Kind = "Luck", Amount = 0.04, Name = "Clean Seas Act", Text = "Rarer fish: +4% luck on every cast" },
	},
	{
		Id = "GA",
		Name = "Golden Anchor",
		Leader = "Lodewijk Terpstra",
		Color = rgb(198, 164, 62),
		Slogan = "Think big, catch big.",
		Policy = { Kind = "Size", Amount = 0.1, Name = "Breeding Programme", Text = "Heavier fish: +10% size boost" },
	},
	{
		Id = "RW",
		Name = "Calm Waters",
		Leader = "Sanne Hoekstra",
		Color = rgb(122, 86, 164),
		Slogan = "No rush, more fish.",
		Policy = { Kind = "Reel", Amount = 0.08, Name = "Calm Waters Act", Text = "Easier fights: +8% reel power and handling" },
	},
}
Parties.ById = {}
for index, party in Parties.List do
	party.Index = index
	Parties.ById[party.Id] = party
end
Parties.POLICY_KINDS = { "XP", "FishPrice", "DishPrice", "Luck", "Size", "Reel" }

-- Terms are numbered from 1; term t covers years 4t-3 to 4t.
function Parties.termOfYear(year: number): number
	return math.floor((year - 1) / Parties.TERM_YEARS) + 1
end

-- In-game seconds since the epoch at which `term` begins.
function Parties.termStart(term: number): number
	return Calendar.elapsedAt((term - 1) * Parties.TERM_YEARS + 1, 1, 1, 0)
end

-- Where the calendar stands, from in-game seconds since the epoch (DayNight.elapsed).
function Parties.state(elapsed: number)
	local date = Calendar.at(elapsed)
	local term = Parties.termOfYear(date.Year)
	local electionYear = term * Parties.TERM_YEARS
	local opensAt = Calendar.elapsedAt(electionYear, Parties.POLLS_OPEN.Month, Parties.POLLS_OPEN.Day, 0)
	local closesAt = Calendar.elapsedAt(electionYear + 1, 1, 1, 0)
	return {
		Term = term,
		Year = date.Year,
		ElectionYear = electionYear,
		OpensAt = opensAt,
		ClosesAt = closesAt,
		PollsOpen = elapsed >= opensAt and elapsed < closesAt,
	}
end

-- One line for boards and the ballot: when the polls close, or when they next open.
function Parties.statusLine(elapsed: number)
	local state = Parties.state(elapsed)
	if state.PollsOpen then
		return string.format("Polls are open until 31 December, year %d", state.ElectionYear), state
	end
	return string.format("Next election: polls open 1 September, year %d", state.ElectionYear), state
end

function Parties.total(votes: { [string]: number }?): number
	local total = 0
	for _, party in Parties.List do
		total += math.max(0, (votes and votes[party.Id]) or 0)
	end
	return total
end

-- The party with the most votes; a tie goes to the party listed first. Nil with no votes.
function Parties.winner(votes: { [string]: number }?): string?
	local best, most = nil, 0
	for _, party in Parties.List do
		local count = (votes and votes[party.Id]) or 0
		if count > most then
			best, most = party.Id, count
		end
	end
	return best
end

-- Seats by the D'Hondt method, as the Tweede Kamer divides its own. With no votes
-- cast the house is split evenly.
function Parties.seats(votes: { [string]: number }?, total: number?): { [string]: number }
	local seats, count = {}, total or Parties.SEATS
	for _, party in Parties.List do
		seats[party.Id] = 0
	end
	if Parties.total(votes) == 0 then
		for index = 1, count do
			local party = Parties.List[(index - 1) % #Parties.List + 1]
			seats[party.Id] += 1
		end
		return seats
	end
	for _ = 1, count do
		local best, quotient = nil, -1
		for _, party in Parties.List do
			local q = math.max(0, (votes :: any)[party.Id] or 0) / (seats[party.Id] + 1)
			if q > quotient then
				best, quotient = party.Id, q
			end
		end
		seats[best :: string] += 1
	end
	return seats
end

-- Policy numbers for a governing party id (all zero when nobody governs).
function Parties.policies(governing: string?): { [string]: number }
	local values = {}
	for _, kind in Parties.POLICY_KINDS do
		values[kind] = 0
	end
	local party = governing and Parties.ById[governing]
	if party then
		values[party.Policy.Kind] = party.Policy.Amount
	end
	return values
end

---------------------------------------------------------------------------------------------------
-- The division bell. It rings three times a day by the clock, and whenever someone rings it
-- from the Speaker's desk. Every member then walks to the Tweede Kamer to vote.

Parties.BELL_HOURS = { 11, 15.5, 20 }
-- In-game seconds: the bell itself, the walk to the benches, the vote and its result.
Parties.BELL = { Ring = 12, Vote = 40, Result = 55, End = 85 }
Parties.BELL_COOLDOWN = 180

-- The division in progress at `elapsed`, if any: when it began and its number.
-- `manual` is the elapsed time of the last hand-rung bell.
function Parties.division(elapsed: number, manual: number?): (number?, number?)
	if manual and elapsed >= manual and elapsed < manual + Parties.BELL.End then
		return manual, math.floor(manual)
	end
	local day = math.floor(elapsed / Calendar.SECONDS_PER_DAY)
	for index, hour in Parties.BELL_HOURS do
		local start = day * Calendar.SECONDS_PER_DAY + hour * (Calendar.SECONDS_PER_DAY / 24)
		if elapsed >= start and elapsed < start + Parties.BELL.End then
			return start, day * #Parties.BELL_HOURS + index
		end
	end
	return nil, nil
end

Parties.MOTIONS = {
	"Motion on lower harbour fees",
	"Night Fishing Bill",
	"Motion on open fish markets",
	"Fisheries Budget",
	"Seabed Protection Bill",
	"Motion on the price of fried fish",
	"Sunday Ferries Bill",
	"Motion on clean harbour water",
	"Lighthouse Modernisation Bill",
	"Motion on larger nets",
	"Crab Cage Amendment",
	"Motion on quiet waters",
	"Shipyard Subsidy Bill",
	"Motion on a metro line to the harbour",
}

local function hash(a: number, b: number): number
	local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - math.floor(v)
end

-- What a numbered division is about and how it ends. The same on every client.
function Parties.motion(number: number)
	local title = Parties.MOTIONS[number % #Parties.MOTIONS + 1]
	local present = 150
	local yes = math.floor(52 + hash(number, 3) * 46 + 0.5)
	return { Title = title, For = yes, Against = present - yes, Adopted = yes > present / 2, Share = yes / present }
end

function Parties.hash(a: number, b: number): number
	return hash(a, b)
end

return Parties
