-- Tuning and layout shared by the café plots (server Map/CafePlots), the café
-- simulation (server CafeService) and the café client (client Cafe).
local CafeCatalog = {}

CafeCatalog.PLOT_TAG = "CafePlot"
CafeCatalog.PROMPT_TAG = "CafePrompt"

-- Each served cup pays this much into the company wallet and this much XP to
-- the barista who served it.
CafeCatalog.COFFEE_PRICE = 20
CafeCatalog.COFFEE_XP = 25
-- Holding the coffee machine's prompt this long brews one cup.
CafeCatalog.BREW_SECONDS = 2.5
-- A customer at the counter waits this long before giving up.
CafeCatalog.PATIENCE = 120
-- Customers inside one café at a time, and seconds between arrivals.
CafeCatalog.MAX_CUSTOMERS = 4
CafeCatalog.ARRIVAL_MIN = 9
CafeCatalog.ARRIVAL_MAX = 16

-- The café floor uses the fishing house's build lattice (Shared.BaseGrid): the
-- customer floor is 11 x 7 cells, the same number of build slots as the house.
-- The staff room adds three rows behind the counter.
CafeCatalog.CELL = 4.5
CafeCatalog.COLUMNS = 11
CafeCatalog.ROWS = 7
CafeCatalog.STAFF_ROWS = 3
CafeCatalog.HALF_WIDTH = CafeCatalog.COLUMNS * CafeCatalog.CELL / 2 -- 24.75
CafeCatalog.FRONT = CafeCatalog.ROWS * CafeCatalog.CELL / 2 -- 15.75, the street wall
CafeCatalog.PARTITION = -CafeCatalog.FRONT -- the wall between the floor and the staff room
CafeCatalog.BACK = CafeCatalog.PARTITION - CafeCatalog.STAFF_ROWS * CafeCatalog.CELL -- -29.25
CafeCatalog.WALL_HEIGHT = 13

-- Café-local points (origin on the customer floor's centre, +Z toward the street).
CafeCatalog.COUNTER_FRONT = -7.65
CafeCatalog.REGISTER_X = -6.75
CafeCatalog.QUEUE_SPACING = 3.2

function CafeCatalog.queueSpot(index: number): Vector3
	return Vector3.new(CafeCatalog.REGISTER_X, 0, CafeCatalog.COUNTER_FRONT + 2.4 + (index - 1) * CafeCatalog.QUEUE_SPACING)
end

CafeCatalog.DOOR_INSIDE = Vector3.new(0, 0, CafeCatalog.FRONT - 2.5)
CafeCatalog.DOOR_OUTSIDE = Vector3.new(0, 0, CafeCatalog.FRONT + 3)
-- Along the pavement in front of the building (four studs deep, kerb to building line).
CafeCatalog.STREET_LEFT = Vector3.new(-22, 0, CafeCatalog.FRONT + 3)
CafeCatalog.STREET_RIGHT = Vector3.new(22, 0, CafeCatalog.FRONT + 3)

return CafeCatalog
