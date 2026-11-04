-- Property rules shared by the purchase screen, map and server transactions.
local CompanyIslands = {}

CompanyIslands.COUNT = 15
CompanyIslands.PRICE = 50000
CompanyIslands.RING_RADIUS = 1600
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
	-- The western bay entrance points between two properties, preserving a
	-- shipping lane while every player has room for a separate company dock.
	local angle = math.rad(-96 + (id - 1) * 360 / CompanyIslands.COUNT)
	return Vector2.new(math.cos(angle), math.sin(angle)) * CompanyIslands.RING_RADIUS
end

function CompanyIslands.frame(id: number): CFrame
	local position = CompanyIslands.position(id)
	-- Every dock faces the main island, leaving the outer shore quiet.
	return CFrame.lookAt(Vector3.new(position.X, 0, position.Y), Vector3.zero)
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
