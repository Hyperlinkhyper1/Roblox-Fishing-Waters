-- Property rules shared by the purchase screen, map and server transactions.
local CompanyIslands = {}

CompanyIslands.COUNT = 15
CompanyIslands.PRICE = 50000
-- Hand-placed around Gullhaven at uneven bearings and distances, so the properties
-- read as a scattered archipelago rather than a ring: { bearing in degrees
-- (atan2 of z over x), distance from the harbour centre, degrees the dock turns
-- away from facing the harbour }. The western shipping entrance (bearing 180) stays
-- open and every property keeps clear of Pirate Cove and the neighbouring biomes.
CompanyIslands.Sites = {
	{ -100, 1480, 12 }, { -78, 1890, -20 }, { -58, 1410, 28 }, { -31, 2050, -8 }, { -12, 1560, 18 },
	{ 9, 1340, -30 }, { 33, 1720, 5 }, { 52, 2180, -15 }, { 71, 1450, 25 }, { 93, 1760, -25 },
	{ 118, 1380, 10 }, { 143, 1990, -12 }, { 158, 1420, 30 }, { 204, 1650, -22 }, { 229, 2280, 15 },
}
-- Includes the long piers and the approach to the harbour mouth.
CompanyIslands.FOOTPRINT = 245
CompanyIslands.TAG = "CompanyIsland"
CompanyIslands.Names = {
	"Pinehaven", "Gullrock", "Lantern Isle", "Saltwind", "Cedar Cay", "Anchor Isle",
	"Driftwood Isle", "Heron Point", "Mossbank", "Seabreeze Cay", "Willow Reach",
	"Mariner Isle", "Pebblehaven", "Osprey Rock", "Tidewatch",
}

function CompanyIslands.validId(id): boolean
	return type(id) == "number" and id % 1 == 0 and id >= 1 and id <= CompanyIslands.COUNT
end

function CompanyIslands.position(id: number): Vector2
	local site = CompanyIslands.Sites[id]
	local angle = math.rad(site[1])
	return Vector2.new(math.cos(angle), math.sin(angle)) * site[2]
end

function CompanyIslands.frame(id: number): CFrame
	local position = CompanyIslands.position(id)
	-- Docks face roughly toward the main island, each turned a little its own way.
	return CFrame.lookAt(Vector3.new(position.X, 0, position.Y), Vector3.zero)
		* CFrame.Angles(0, math.rad(CompanyIslands.Sites[id][3]), 0)
end

-- The fenced building plot on the upper terrace, centred this far behind the
-- island's centre with its surface at this height (island-local studs). Its
-- frame is where company furniture is measured from (FurnitureCatalog.PLOT).
CompanyIslands.PLOT_Z = 40
CompanyIslands.PLOT_HEIGHT = 24.56

-- The terrace stair is cut into the cliff front: its foot on the beach and its head
-- on the terrace short of the plot gate, in world space for walking NPCs.
function CompanyIslands.stairEnds(islandFrame: CFrame): (Vector3, Vector3)
	return islandFrame * Vector3.new(0, 4.4, -42), islandFrame * Vector3.new(0, 24.4, 4)
end

function CompanyIslands.plotFrame(id: number): CFrame
	return CompanyIslands.frame(id) * CFrame.new(0, CompanyIslands.PLOT_HEIGHT, CompanyIslands.PLOT_Z)
end

function CompanyIslands.purchaseProblem(profile): string?
	if not profile then
		return "Your progress is still loading."
	elseif profile.Angler.CompanyIsland then
		return "You already own a company island."
	elseif not (profile.Angler.Paths and profile.Angler.Paths.Unlocked.Company) then
		return "Unlock The Company in Home > Paths first."
	elseif profile.Cash < CompanyIslands.PRICE then
		return "A company island costs $50,000."
	end
	return nil
end

-- Called inside the wallet's UpdateAsync callback; never mutates the input.
function CompanyIslands.purchase(profile, id: number)
	local problem = CompanyIslands.purchaseProblem(profile)
	if problem then
		return nil, problem
	elseif not CompanyIslands.validId(id) then
		return nil, "Choose an available company island."
	end
	local result = table.clone(profile)
	result.Angler = table.clone(profile.Angler)
	result.Angler.CompanyIsland = id
	result.Angler.Stats = table.clone(profile.Angler.Stats or {})
	result.Angler.Stats.CoinsSpent = (result.Angler.Stats.CoinsSpent or 0) + CompanyIslands.PRICE
	result.Cash -= CompanyIslands.PRICE
	return result
end

return CompanyIslands
