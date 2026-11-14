-- Café and company-branch rules (spliced by scripts/check-cafe.mjs).
local Branches = (function()
-- BRANCHES_SOURCE --
end)()
local SaveData = (function()
-- SAVE_DATA_SOURCE --
end)()
local CafeCatalog = (function()
-- CAFE_CATALOG_SOURCE --
end)()

local checks = 0
local function check(condition, message)
	checks += 1
	if not condition then
		error("FAILED: " .. message, 2)
	end
end
local function fails(callback, fragment)
	local ok, problem = pcall(callback)
	return not ok and string.find(tostring(problem), fragment, 1, true) ~= nil
end

-- Existing saves have no branches: they stay fishing companies.
check(Branches.has({}, "Fishing") and not Branches.has({}, "Cafe"), "Saves from before branches are fishing companies")
check(Branches.has({ Branches = { Cafe = true } }, "Cafe") and not Branches.has({ Branches = { Cafe = true } }, "Fishing"), "A café save has only the café branch")
check(Branches.has({ Branches = { Retired = true } }, "Fishing"), "Unknown branches fall back to fishing")
check(Branches.label(nil) == "Fishing" and Branches.label({ Cafe = true }) == "Café", "Branch labels")
check(Branches.label({ Cafe = true, Fishing = true }) == "Fishing + Café", "Both branches are listed in order")
check(fails(function() Branches.normalize({ Cafe = "yes" }) end, "Invalid company branch"), "Malformed branches are rejected")
check(Branches.starting("Cafe").Cafe and not Branches.starting("Cafe").Fishing, "A new café starts with only the café branch")
check(Branches.starting(nil).Fishing, "The default company type is fishing")

-- Buying the other branch.
local price = Branches.Info.Cafe.Price
local poor = { Cash = price - 1 }
check(fails(function() Branches.buy(poor, "Cafe") end, "cash"), "A branch costs its price")
check(poor.Cash == price - 1 and poor.Branches == nil, "A refused purchase changes nothing")
local fisher = { Cash = price + 10 }
Branches.buy(fisher, "Cafe")
check(fisher.Cash == 10 and fisher.Branches.Fishing and fisher.Branches.Cafe, "A fishing company buys the café branch and keeps fishing")
check(fails(function() Branches.buy(fisher, "Cafe") end, "already"), "A branch is bought once")
local cafe = { Cash = Branches.Info.Fishing.Price, Branches = { Cafe = true } }
Branches.buy(cafe, "Fishing")
check(cafe.Cash == 0 and cafe.Branches.Fishing and cafe.Branches.Cafe, "A café company buys the fishing branch")
check(fails(function() Branches.buy({ Cash = 1e9 }, "Bakery") end, "Unknown branch"), "Only catalog branches can be bought")

-- Save creation picks the company type.
check(SaveData.cleanCompanyType(nil) == "Fishing" and SaveData.cleanCompanyType("Cafe") == "Cafe", "Company types")
check(fails(function() SaveData.cleanCompanyType("Bakery") end, "Choose a fishing company or a café"), "Unknown company types are rejected")
for kind in SaveData.COMPANY_TYPES do
	check(Branches.valid(kind), "Every company type is a branch: " .. kind)
end

-- The café floor is the fishing house's build lattice; customers queue inside it.
check(CafeCatalog.COLUMNS == 11 and CafeCatalog.ROWS == 7 and CafeCatalog.CELL == 4.5, "Same build slots as the fishing house (11 x 7)")
for index = 1, CafeCatalog.MAX_CUSTOMERS do
	local spot = CafeCatalog.queueSpot(index)
	check(spot.Z > CafeCatalog.COUNTER_FRONT + 1 and spot.Z < CafeCatalog.FRONT - 2, "Queue spot " .. index .. " is on the customer floor")
	check(math.abs(spot.X) < CafeCatalog.HALF_WIDTH - 1, "Queue spot " .. index .. " is inside the walls")
end
-- Customers walk up and down the pavement, never the avenue (pavement: four studs out from the front wall).
for _, point in { CafeCatalog.STREET_LEFT, CafeCatalog.STREET_RIGHT, CafeCatalog.DOOR_OUTSIDE } do
	check(point.Z > CafeCatalog.FRONT + 0.8 and point.Z < CafeCatalog.FRONT + 0.8 + 4, "Street points are on the pavement")
end

-- City café sites: one per harbour plot, each café inside its own block.
local sites = CAFE_SITES()
check(#sites == HARBOUR_BASES, string.format("One café per harbour plot (%d cafés, %d plots)", #sites, HARBOUR_BASES))
-- Each café is the ground floor of the block's avenue building (Map/CafePlots), on the
-- building line behind the four-stud pavement, with a building behind it on the back street.
local WALL, SETBACK, YARD = 0.8, 4, 3
local halfWidth = CafeCatalog.HALF_WIDTH + WALL
local depth = (CafeCatalog.FRONT - CafeCatalog.BACK) + 2 * WALL
for index, site in sites do
	check((site.w - 2 * SETBACK) / 2 - halfWidth >= 0.5, "Café " .. index .. " fits inside its building's width")
	check(site.d - 2 * SETBACK - depth - YARD >= 8, "Café " .. index .. " leaves room for the building behind it")
	for other = index + 1, #sites do
		local a, b = site.cframe.Position, sites[other].cframe.Position
		check((a - b).Magnitude > 60, "Cafés " .. index .. " and " .. other .. " have separate blocks")
	end
end
print("Café and branches: " .. checks .. " checks passed (pure rules and city layout)")
