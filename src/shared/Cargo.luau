-- Inventory capacity shared by gameplay and the client. Shape areas retain each
-- fish/part's original space cost; placement and rotation no longer limit storage.
-- Legacy coordinates and geometry helpers remain readable for older saved data.
--
-- Shapes and hold masks are rows of text read top to bottom: "#" is a filled
-- cell, "." is empty. Items sit at X, Y (1-based, the top-left of the rotated
-- shape's bounding box) with R quarter turns clockwise.
local Cargo = {}

-- Boat kit stowed in a hold. It can be rearranged and rotated, but never
-- released or frozen. Motors and rudders can be added at the refit dock
-- (Shared.BoatUpgrades).
Cargo.Parts = {
	Engine = { Name = "Inboard engine", Shape = { "##", "##" }, Motor = true },
	PatrolEngine = { Name = "Inboard engine", Shape = { "###", "###", "###", "###" }, Motor = true },
	-- Broad engine bed across the trawler's transom, with a twin-cell shaft trunk forward.
	TrawlerEngine = { Name = "Inboard engine", Shape = { ".##.", ".##.", "####" }, Motor = true },
	Lantern = { Name = "Deck lantern", Shape = { "#" } },
	Rudder = { Name = "Rudder", Shape = { "#", "#" } },
}

-- Species without their own Shapes in the catalog still grow with their size class.
local FALLBACK = { Normal = { "#" }, Big = { "##" }, Huge = { "##", "##" } }

-- Returns the filled cells as { dx, dy } offsets (0-based) plus the rotated width and height.
function Cargo.cells(rows: { string }, rotation: number?): ({ { number } }, number, number)
	local cells, width, height = {}, 0, #rows
	for y, row in rows do
		width = math.max(width, #row)
		for x = 1, #row do
			if string.sub(row, x, x) == "#" then
				table.insert(cells, { x - 1, y - 1 })
			end
		end
	end
	for _ = 1, (rotation or 0) % 4 do
		for index, cell in cells do
			cells[index] = { height - 1 - cell[2], cell[1] }
		end
		width, height = height, width
	end
	return cells, width, height
end

-- Accepts a hold item ({ Fish = record } or { PartId = ... }) or a bare fish record.
function Cargo.shape(item, species): { string }
	if item.PartId then
		local part = Cargo.Parts[item.PartId]
		return if part then part.Shape else FALLBACK.Normal
	end
	local fish = item.Fish or item
	local entry = species[fish.FishId]
	local shapes = if entry and entry.Shapes then entry.Shapes else FALLBACK
	return shapes[fish.Size or "Normal"] or shapes.Normal or FALLBACK.Normal
end

function Cargo.open(mask: { string }, x: number, y: number): boolean
	local row = mask[y]
	return row ~= nil and x >= 1 and string.sub(row, x, x) == "#"
end

-- A hold whose metatable reports Infinite (the Black Hole Backpack) never fills.
-- Its legacy rows remain readable by backpack models and older saves.
function Cargo.capacity(mask: { string }): number
	if (mask :: any).Infinite then
		return math.huge
	end
	return #Cargo.cells(mask)
end

local function key(x: number, y: number): number
	return y * 256 + x
end

-- Maps every filled cell to the index of the item covering it, ignoring `skip`
-- (the item being moved).
function Cargo.occupied(items, species, skip: number?): { [number]: number }
	local taken = {}
	for index, item in items do
		if index ~= skip then
			for _, cell in Cargo.cells(Cargo.shape(item, species), item.R) do
				taken[key(item.X + cell[1], item.Y + cell[2])] = index
			end
		end
	end
	return taken
end

function Cargo.at(taken, x: number, y: number): number?
	return taken[key(x, y)]
end

function Cargo.fits(mask: { string }, taken, shape: { string }, x: number, y: number, rotation: number): boolean
	for _, cell in Cargo.cells(shape, rotation) do
		local cx, cy = x + cell[1], y + cell[2]
		if not Cargo.open(mask, cx, cy) or taken[key(cx, cy)] then
			return false
		end
	end
	return true
end

function Cargo.space(item, species): number
	return #Cargo.cells(Cargo.shape(item, species))
end

function Cargo.used(items, species, skip: number?): number
	local used = 0
	for index, item in items do
		if index ~= skip then
			used += Cargo.space(item, species)
		end
	end
	return used
end

-- The placeholder coordinates keep saves compatible with older profiles. They
-- do not describe occupied slots and must never be used to calculate free space.
function Cargo.bestSpot(mask, items, item, species, skip: number?)
	if Cargo.used(items, species, skip) + Cargo.space(item, species) <= Cargo.capacity(mask) then
		return { X = 1, Y = 1, R = 0 }
	end
	return nil
end

return Cargo
