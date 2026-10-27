-- Refit dock upgrades. Extra motors and rudders are boat kit stowed in the cargo
-- hold (Shared.Cargo parts), so every one fitted costs hold tiles; the boat's own
-- kit from BoatCatalog.StarterParts never counts as an upgrade. Paint is a saved
-- preset colour per boat. Pure: the saved-data tests run it without Roblox.
local Cargo = if script then require(script.Parent.Cargo) else require("./Cargo")

local BoatUpgrades = {}

BoatUpgrades.Order = { "Motor", "Rudder" }
BoatUpgrades.Kinds = {
	-- Boost is the share of the stock figure each fitted part adds.
	Motor = {
		Name = "Extra motor",
		Plural = "motors",
		Max = 3,
		Boost = 0.12,
		Description = "Each one adds 12% top speed and acceleration.",
	},
	Rudder = {
		Name = "Rudder",
		Plural = "rudders",
		Max = 3,
		Boost = 0.15,
		Description = "Each one turns the hull 15% sharper and quicker.",
	},
}

-- The trawler's stern net is a permanent hull fitting, not hold cargo. It is
-- saved apart from the motor and rudder kit so it never consumes cargo tiles.
BoatUpgrades.Net = {
	Id = "FishermansNet",
	Name = "Fisherman's Net",
	BoatId = "Trawler",
	Price = 5000,
	Description = "Trawls the stern while underway. Catches common fish, and sometimes uncommon ones.",
}

-- Preset hull colours as RGB, so this module needs no Roblox types. Factory puts
-- the builder's own colours back.
BoatUpgrades.Paints = {
	{ Id = "Factory", Name = "Factory finish" },
	{ Id = "White", Name = "White", RGB = { 238, 240, 236 } },
	{ Id = "Black", Name = "Black", RGB = { 36, 38, 42 } },
	{ Id = "Gray", Name = "Gray", RGB = { 128, 134, 140 } },
	{ Id = "Red", Name = "Red", RGB = { 196, 40, 40 } },
	{ Id = "Orange", Name = "Orange", RGB = { 232, 118, 36 } },
	{ Id = "Yellow", Name = "Yellow", RGB = { 240, 196, 48 } },
	{ Id = "Green", Name = "Green", RGB = { 46, 139, 70 } },
	{ Id = "Blue", Name = "Blue", RGB = { 36, 104, 196 } },
	{ Id = "Navy", Name = "Navy", RGB = { 28, 44, 92 } },
	{ Id = "Purple", Name = "Purple", RGB = { 120, 64, 168 } },
	{ Id = "Pink", Name = "Pink", RGB = { 232, 120, 168 } },
}

function BoatUpgrades.paint(id: any)
	for _, paint in BoatUpgrades.Paints do
		if paint.Id == id then
			return paint
		end
	end
	return nil
end

-- Whether this angler has bought the trawler's stern net. Profiles from before
-- the net existed simply have no BoatUpgrades table yet.
function BoatUpgrades.ownsNet(angler)
	local boats = type(angler) == "table" and angler.BoatUpgrades
	local upgrades = type(boats) == "table" and boats[BoatUpgrades.Net.BoatId]
	return type(upgrades) == "table" and upgrades[BoatUpgrades.Net.Id] == true
end

function BoatUpgrades.grantNet(angler)
	local boatId = BoatUpgrades.Net.BoatId
	angler.BoatUpgrades = angler.BoatUpgrades or {}
	angler.BoatUpgrades[boatId] = angler.BoatUpgrades[boatId] or {}
	angler.BoatUpgrades[boatId][BoatUpgrades.Net.Id] = true
	return angler
end

-- Extra motors match the boat's own engine; a hull without one (the rowboat)
-- takes the small inboard engine.
function BoatUpgrades.partId(layout, kind: string): string
	if kind == "Rudder" then
		return "Rudder"
	end
	for _, item in layout.StarterParts or {} do
		local part = Cargo.Parts[item.PartId]
		if part and part.Motor then
			return item.PartId
		end
	end
	return "Engine"
end

function BoatUpgrades.tiles(layout, kind: string): number
	return #Cargo.cells(Cargo.Parts[BoatUpgrades.partId(layout, kind)].Shape)
end

-- How many of `kind` were fitted at the refit dock, beyond the boat's own kit.
function BoatUpgrades.count(items, layout, kind: string): number
	local partId = BoatUpgrades.partId(layout, kind)
	local count = 0
	for _, item in items do
		if item.PartId == partId then
			count += 1
		end
	end
	for _, item in layout.StarterParts or {} do
		if item.PartId == partId then
			count -= 1
		end
	end
	return math.max(count, 0)
end

-- The catalog spec with `motors` extra motors and `rudders` rudders fitted.
function BoatUpgrades.tuned(layout, motors: number, rudders: number)
	if motors == 0 and rudders == 0 then
		return layout
	end
	local spec = table.clone(layout)
	local speed = 1 + motors * BoatUpgrades.Kinds.Motor.Boost
	local turn = 1 + rudders * BoatUpgrades.Kinds.Rudder.Boost
	spec.ForwardSpeed *= speed
	spec.ReverseSpeed *= speed
	spec.Acceleration *= speed
	spec.TurnRate *= turn
	spec.TurnAcceleration *= turn
	return spec
end

-- The spec a hull drives with, given its saved hold.
function BoatUpgrades.spec(layout, items)
	return BoatUpgrades.tuned(
		layout,
		BoatUpgrades.count(items, layout, "Motor"),
		BoatUpgrades.count(items, layout, "Rudder")
	)
end

function BoatUpgrades.freeTiles(layout, items, species): number
	local used = 0
	for _ in Cargo.occupied(items, species) do
		used += 1
	end
	return math.max(Cargo.capacity(layout.Hold) - used, 0)
end

-- Returns a copy of the hold with one more `kind` stowed in the best open spot,
-- or nil and a player-facing reason.
function BoatUpgrades.install(items, layout, kind: string, species)
	local upgrade = BoatUpgrades.Kinds[kind]
	if not upgrade then
		return nil, "Choose a motor or a rudder."
	elseif BoatUpgrades.count(items, layout, kind) >= upgrade.Max then
		return nil, string.format("Your %s already has %d extra %s.", layout.Name, upgrade.Max, upgrade.Plural)
	end
	local partId = BoatUpgrades.partId(layout, kind)
	local spot = Cargo.bestSpot(layout.Hold, items, { PartId = partId }, species)
	if not spot then
		return nil,
			string.format(
				"There's no room in your hold. Clear %d cargo tiles in one place first.",
				BoatUpgrades.tiles(layout, kind)
			)
	end
	local result = table.clone(items)
	table.insert(result, { PartId = partId, X = spot.X, Y = spot.Y, R = spot.R })
	return result
end

-- Returns a copy of the hold with the last fitted `kind` taken out. The boat's own
-- kit always stays aboard.
function BoatUpgrades.remove(items, layout, kind: string)
	local upgrade = BoatUpgrades.Kinds[kind]
	if not upgrade then
		return nil, "Choose a motor or a rudder."
	elseif BoatUpgrades.count(items, layout, kind) == 0 then
		return nil, string.format("Your %s has no extra %s to take out.", layout.Name, upgrade.Plural)
	end
	local partId = BoatUpgrades.partId(layout, kind)
	local result = table.clone(items)
	for index = #result, 1, -1 do
		if result[index].PartId == partId then
			table.remove(result, index)
			break
		end
	end
	return result
end

-- Whether `position` is inside a refit dock's slip (its SlipFrame and SlipSize).
function BoatUpgrades.inSlip(dock: Instance, position: Vector3): boolean
	local frame, size = dock:GetAttribute("SlipFrame"), dock:GetAttribute("SlipSize")
	if typeof(frame) ~= "CFrame" or typeof(size) ~= "Vector3" then
		return false
	end
	local point = frame:PointToObjectSpace(position)
	return math.abs(point.X) <= size.X / 2 and math.abs(point.Y) <= size.Y / 2 and math.abs(point.Z) <= size.Z / 2
end

return BoatUpgrades
