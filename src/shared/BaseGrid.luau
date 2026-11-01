-- House-local building and navigation grid. The origin is the house center.
local BaseGrid = {}

BaseGrid.CELL_SIZE = 4.5
BaseGrid.COLUMNS = 11
BaseGrid.ROWS = 7
BaseGrid.HALF_WIDTH = BaseGrid.COLUMNS * BaseGrid.CELL_SIZE / 2
BaseGrid.HALF_LENGTH = BaseGrid.ROWS * BaseGrid.CELL_SIZE / 2

-- The same lattice continues over the quay, both piers, the road out front and
-- the shop across it. These bounds are expressed in the house's 1-based cell
-- coordinates: column 6 and row 4 are centered on HouseFrame. The outermost
-- cells include the dock tips and the back of the shop; occupancy is
-- determined from the actual walking surface.
BaseGrid.BASE_MIN_COLUMN = -2
BaseGrid.BASE_MAX_COLUMN = 14
BaseGrid.BASE_MIN_ROW = -18
BaseGrid.BASE_MAX_ROW = 22

-- The customer shop is its own building across the ring road, in the same
-- house-local frame: its front wall faces the house at SHOP_FRONT and its back
-- wall is at SHOP_BACK. Its floor plan is the old in-house shop room turned half
-- a circle about (0, SHOP_TURN / 2), so (x, z) there is (-x, SHOP_TURN - z) here.
BaseGrid.SHOP_FRONT = 65.25
BaseGrid.SHOP_BACK = 83.25
BaseGrid.SHOP_TURN = 81

-- Snap any house-local coordinate to the same lattice, including extensions.
function BaseGrid.snap(value: number): number
	return math.round(value / BaseGrid.CELL_SIZE) * BaseGrid.CELL_SIZE
end

-- 1-based columns and rows run from negative to positive X and Z.
function BaseGrid.localToCell(x: number, z: number): (number?, number?)
	if x < -BaseGrid.HALF_WIDTH or x >= BaseGrid.HALF_WIDTH
		or z < -BaseGrid.HALF_LENGTH or z >= BaseGrid.HALF_LENGTH then
		return nil, nil
	end
	return math.floor((x + BaseGrid.HALF_WIDTH) / BaseGrid.CELL_SIZE) + 1,
		math.floor((z + BaseGrid.HALF_LENGTH) / BaseGrid.CELL_SIZE) + 1
end

function BaseGrid.cellToLocal(column: number, row: number): (number, number)
	return -BaseGrid.HALF_WIDTH + (column - 0.5) * BaseGrid.CELL_SIZE,
		-BaseGrid.HALF_LENGTH + (row - 0.5) * BaseGrid.CELL_SIZE
end

function BaseGrid.extendedCellToLocal(column: number, row: number): (number, number)
	return BaseGrid.cellToLocal(column, row)
end

function BaseGrid.localToExtendedCell(x: number, z: number): (number?, number?)
	local column = math.floor((x + BaseGrid.HALF_WIDTH) / BaseGrid.CELL_SIZE) + 1
	local row = math.floor((z + BaseGrid.HALF_LENGTH) / BaseGrid.CELL_SIZE) + 1
	if column < BaseGrid.BASE_MIN_COLUMN or column > BaseGrid.BASE_MAX_COLUMN
		or row < BaseGrid.BASE_MIN_ROW or row > BaseGrid.BASE_MAX_ROW then
		return nil, nil
	end
	return column, row
end

return BaseGrid
