-- Pure refit dock checks: motors and rudders as hold parts, their tile cost and
-- speed/turn boosts, and saved paint. Run: lute run scripts/boat-upgrades.luau.
-- No Roblox runtime.
local AnglerData = require("../src/server/AnglerData")
local BoatCatalog = require("../src/shared/BoatCatalog")
local BoatUpgrades = require("../src/shared/BoatUpgrades")
local Cargo = require("../src/shared/Cargo")
local TrawlerNet = require("../src/shared/TrawlerNet")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local species = { Trout = { Shapes = { Normal = { "##" } } } }
local function fish(at)
	return { FishId = "Trout", Mutation = "Normal", Kg = 2, Value = 10, Rarity = 10, Relative = 1, CaughtAt = at }
end

-- Every boat's motor matches its own engine; the rowboat takes the small inboard.
check(BoatUpgrades.partId(BoatCatalog.FishingBoat, "Motor") == "Engine", "Fishing boat motor")
check(BoatUpgrades.partId(BoatCatalog.PatrolBoat, "Motor") == "PatrolEngine", "Patrol motor matches its engine")
check(BoatUpgrades.partId(BoatCatalog.Rowboat, "Motor") == "Engine", "Rowboat takes the small inboard")
check(BoatUpgrades.partId(BoatCatalog.Rowboat, "Rudder") == "Rudder", "Rudder part")
check(BoatUpgrades.tiles(BoatCatalog.FishingBoat, "Motor") == 4, "A motor costs four tiles")
check(BoatUpgrades.tiles(BoatCatalog.PatrolBoat, "Motor") == 12, "A patrol motor costs twelve tiles")
check(BoatUpgrades.tiles(BoatCatalog.Speedboat, "Rudder") == 2, "A rudder costs two tiles")

for id, layout in BoatCatalog do
	local kit = AnglerData.hold({}, id, layout)
	check(BoatUpgrades.count(kit, layout, "Motor") == 0, id .. ": its own engine is not an upgrade")
	check(BoatUpgrades.count(kit, layout, "Rudder") == 0, id .. ": no rudders from the yard")
	check(BoatUpgrades.spec(layout, kit) == layout, id .. ": a stock hold drives at catalog figures")
	check(BoatUpgrades.remove(kit, layout, "Motor") == nil, id .. ": the boat's own engine stays aboard")

	-- Fit to the limit; each motor costs its tiles and adds speed, not turning.
	local items, free = kit, BoatUpgrades.freeTiles(layout, kit, species)
	for count = 1, BoatUpgrades.Kinds.Motor.Max do
		local fitted, reason = BoatUpgrades.install(items, layout, "Motor", species)
		check(fitted, id .. ": motor " .. count .. " fits: " .. tostring(reason))
		check(#items == #fitted - 1, id .. ": install copies the hold")
		items = fitted
		check(BoatUpgrades.count(items, layout, "Motor") == count, id .. ": motor counted")
		check(
			BoatUpgrades.freeTiles(layout, items, species) == free - count * BoatUpgrades.tiles(layout, "Motor"),
			id .. ": motors use cargo tiles"
		)
		local spec = BoatUpgrades.spec(layout, items)
		check(math.abs(spec.ForwardSpeed - layout.ForwardSpeed * (1 + 0.12 * count)) < 1e-9, id .. ": top speed")
		check(spec.Acceleration > layout.Acceleration, id .. ": acceleration")
		check(spec.TurnRate == layout.TurnRate, id .. ": motors leave turning alone")
		check(spec.Name == layout.Name and spec.Hold == layout.Hold, id .. ": tuned spec keeps the hull")
	end
	local _, maxed = BoatUpgrades.install(items, layout, "Motor", species)
	check(maxed and string.find(maxed, "already has"), id .. ": motor limit")

	local rudders = assert(BoatUpgrades.install(items, layout, "Rudder", species))
	local spec = BoatUpgrades.spec(layout, rudders)
	check(math.abs(spec.TurnRate - layout.TurnRate * 1.15) < 1e-9, id .. ": rudder sharpens turns")
	check(spec.TurnAcceleration > layout.TurnAcceleration, id .. ": rudder quickens turns")

	-- Taking a motor out frees its tiles and never touches the kit.
	local removed = assert(BoatUpgrades.remove(rudders, layout, "Motor"))
	check(BoatUpgrades.count(removed, layout, "Motor") == BoatUpgrades.Kinds.Motor.Max - 1, id .. ": one motor out")
	check(BoatUpgrades.count(removed, layout, "Rudder") == 1, id .. ": rudder stays")
	for _, item in kit do
		local still = false
		for _, left in removed do
			still = still or (left.PartId == item.PartId and left.X == item.X and left.Y == item.Y)
		end
		check(still, id .. ": kit stays where it was")
	end
end

-- A full hold has no room for a motor, and the reason says how many tiles to clear.
local layout = BoatCatalog.Rowboat
local full = AnglerData.hold({}, "Rowboat", layout)
while true do
	local spot = Cargo.bestSpot(layout.Hold, full, { Fish = fish(#full) }, species)
	if not spot then
		break
	end
	table.insert(full, { Fish = fish(#full), X = spot.X, Y = spot.Y, R = spot.R })
end
local none, reason = BoatUpgrades.install(full, layout, "Motor", species)
check(none == nil and string.find(reason, "4 cargo tiles"), "A full hold refuses a motor")
check(BoatUpgrades.install(full, layout, "Sail", species) == nil, "Unknown upgrades are refused")

-- Fitted parts are ordinary hold kit: they move like the engine and never leave the hold.
local fitted = assert(BoatUpgrades.install(AnglerData.hold({}, "Rowboat", layout), layout, "Rudder", species))
local saved = AnglerData.decode({ Holds = { Rowboat = fitted } })
local index = #saved.Holds.Rowboat
check(saved.Holds.Rowboat[index].PartId == "Rudder", "A rudder saves in the hold")
local _, released = AnglerData.moveCargo(saved, "Rowboat", layout, index, "Release", species)
check(released == "Boat parts stay in the hold.", "A rudder can't be thrown overboard")
local _, handed = AnglerData.moveCargo(saved, "Rowboat", layout, index, "Hand", species)
check(handed == "Boat parts stay in the hold.", "A rudder can't be carried off")

-- Refits fitted by hand land exactly on the tiles the player chose.
local manual = assert(AnglerData.placePart(AnglerData.decode({}), "Rowboat", layout, "Rudder", 1, 4, 0, species))
local manualHold = AnglerData.hold(manual, "Rowboat", layout)
check(#manualHold == #AnglerData.hold({}, "Rowboat", layout) + 1, "A manual rudder joins the hold")
check(BoatUpgrades.count(manualHold, layout, "Rudder") == 1, "A manual rudder counts as fitted")
check(BoatUpgrades.spec(layout, manualHold).TurnRate > layout.TurnRate, "A manual rudder sharpens turning")
check(
	AnglerData.placePart(manual, "Rowboat", layout, "Rudder", 1, 4, 0, species) == nil,
	"Overlapping manual placement is refused"
)
check(
	AnglerData.placePart(manual, "Rowboat", layout, "Rudder", 0, 1, 0, species) == nil,
	"Off-grid manual placement is refused"
)

-- Paint: presets are unique, valid colours, and saved per boat.
local seen = {}
for _, paint in BoatUpgrades.Paints do
	check(not seen[paint.Id], "Paint ids are unique")
	seen[paint.Id] = true
	check(BoatUpgrades.paint(paint.Id) == paint, "Paints look up by id")
	if paint.Id ~= "Factory" then
		check(#paint.RGB == 3, paint.Id .. " has an RGB colour")
		for _, channel in paint.RGB do
			check(channel >= 0 and channel <= 255 and channel % 1 == 0, paint.Id .. " channel in range")
		end
	end
end
check(BoatUpgrades.paint("Factory").RGB == nil, "Factory keeps the builder's colours")
check(BoatUpgrades.paint("Chartreuse") == nil, "Only preset paints")
check(next(AnglerData.decode(nil).BoatPaint) == nil, "New profiles start unpainted")
check(AnglerData.decode({ BoatPaint = { Speedboat = "Red" } }).BoatPaint.Speedboat == "Red", "Paint is saved")
check(not pcall(AnglerData.decode, { BoatPaint = { Speedboat = 4 } }), "Malformed paint is rejected")
check(not pcall(AnglerData.decode, { BoatPaint = "Red" }), "Malformed paint table is rejected")

-- The fisherman's net is a permanent trawler fitting, saved apart from paint
-- and the cargo-hold kit.
local net = BoatUpgrades.Net
check(net.Price == 5000 and net.BoatId == "Trawler", "The net is a $5,000 trawler fitting")
local freshNet = AnglerData.decode(nil)
check(not BoatUpgrades.ownsNet(freshNet), "New anglers do not own the net")
check(not BoatUpgrades.ownsNet({ BoatUpgrades = { Trawler = { FishermansNet = 1 } } }), "Net ownership is boolean")
BoatUpgrades.grantNet(freshNet)
check(BoatUpgrades.ownsNet(freshNet), "Buying the net saves its ownership")
check(not BoatUpgrades.ownsNet({ BoatUpgrades = { Speedboat = { FishermansNet = true } } }), "The net is trawler-only")
check(
	AnglerData.decode({ BoatUpgrades = { Trawler = { FishermansNet = true } } }).BoatUpgrades.Trawler.FishermansNet,
	"Saved net ownership decodes"
)
check(
	not pcall(AnglerData.decode, { BoatUpgrades = { Trawler = { FishermansNet = 1 } } }),
	"Malformed net ownership is rejected"
)
check(not pcall(AnglerData.decode, { BoatUpgrades = "Trawler" }), "Malformed boat upgrades table is rejected")

-- Pure stand-ins for the real catalog, so this test needs no Roblox Color3.
local netSpecies = {
	Trout = {
		Name = "Trout",
		Rarity = "Common",
		CatchXP = 50,
		RarityDenominator = 4,
		MinKg = 0.3,
		AverageKg = 1.2,
		MaxKg = 9,
		BaseValue = 10,
		Fight = 0.04,
		Shapes = { Normal = { "##" } },
	},
	Carp = {
		Name = "Carp",
		Rarity = "Common",
		CatchXP = 50,
		RarityDenominator = 4,
		MinKg = 0.8,
		AverageKg = 3.5,
		MaxKg = 30,
		BaseValue = 9,
		Fight = 0.02,
		Shapes = { Normal = { "##", "##" } },
	},
	Cod = {
		Name = "Cod",
		Rarity = "Uncommon",
		CatchXP = 100,
		RarityDenominator = 9,
		MinKg = 1,
		AverageKg = 4,
		MaxKg = 40,
		BaseValue = 24,
		Fight = 0.02,
		Shapes = { Normal = { "###" } },
	},
	Bluegill = {
		Name = "Bluegill",
		Rarity = "Uncommon",
		CatchXP = 100,
		RarityDenominator = 9,
		MinKg = 0.1,
		AverageKg = 0.35,
		MaxKg = 2,
		BaseValue = 20,
		Shapes = { Normal = { "#" } },
	},
	Stingray = {
		Name = "Stingray",
		Rarity = "Legendary",
		CatchXP = 800,
		RarityDenominator = 150,
		MinKg = 6,
		AverageKg = 25,
		MaxKg = 180,
		BaseValue = 500,
		Fight = 0.06,
		Shapes = { Normal = { "##.", "###", "##." } },
	},
}
local netRarities = {
	Common = { Difficulty = 0.12 },
	Uncommon = { Difficulty = 0.3 },
	Legendary = { Difficulty = 0.72 },
}
local netMutations = { Normal = {} }
local netPool = { Fish = { "Trout", "Carp", "Cod", "Bluegill", "Stingray" } }

-- Net catches land in the hold and still count in the bestiary, XP and findings.
local netRoll = { FishId = "Trout", Kg = 1.2, Size = "Normal", Value = 10, Relative = 1 }
local netted = assert(
	AnglerData.netCatch(freshNet, "Trawler", BoatCatalog.Trawler, netRoll, 1000, netSpecies, netMutations)
)
check(netted.Stats.TotalCaught == 1, "A net catch counts in lifetime catches")
check(netted.Stats.TotalXP == netSpecies.Trout.CatchXP, "A net catch awards species XP")
check(netted.Stats.CatchStreak == 1 and netted.Stats.HighestCatchStreak == 1, "A net catch extends the streak")
check(netted.Catches.Trout.Count == 1 and netted.Catches.Trout.BiggestKg == 1.2, "A net catch fills the bestiary")
check(netted.Findings.Largest.FishId == "Trout", "A net catch can set a finding")
check(netted.Hand == nil, "A net catch never fills the hand")
local netStowed = false
for _, item in netted.Holds.Trawler do
	if item.Fish and item.Fish.FishId == "Trout" then
		netStowed = true
	end
end
check(netStowed, "A net catch is stowed in the trawler hold")

-- The net only rolls common and uncommon fish; the rare tiers are excluded.
check(TrawlerNet.UncommonChance == 0.2, "Uncommon fish are the occasional net catch")
check(TrawlerNet.MinSpeed > 0 and TrawlerNet.MinSeconds < TrawlerNet.MaxSeconds, "Net movement and timer tuning is sane")
local common, uncommon = TrawlerNet.candidates(netPool, netSpecies)
check(#common == 2 and #uncommon == 2, "Only common and uncommon species are net candidates")
for _, id in common do
	check(netSpecies[id].Rarity == "Common", "Common candidate: " .. id)
end
for _, id in uncommon do
	check(netSpecies[id].Rarity == "Uncommon", "Uncommon candidate: " .. id)
end
local function sequence(...)
	local values = table.pack(...)
	local index = 0
	return function()
		index += 1
		return values[index] or 0.5
	end
end
local uncommonRoll = assert(TrawlerNet.roll(netPool, netSpecies, netRarities, sequence(0.01, 0.5)))
check(netSpecies[uncommonRoll.FishId].Rarity == "Uncommon", "A low net roll lands an uncommon")
local commonRoll = assert(TrawlerNet.roll(netPool, netSpecies, netRarities, sequence(0.99, 0.5)))
check(netSpecies[commonRoll.FishId].Rarity == "Common", "A normal net roll lands a common")
check(
	TrawlerNet.roll({ Fish = { "Stingray" } }, netSpecies, netRarities, sequence(0.5)) == nil,
	"A pool with no common or uncommon fish catches nothing"
)
check(TrawlerNet.nextInterval(sequence(0)) == TrawlerNet.MinSeconds, "The fastest net timer")
check(TrawlerNet.nextInterval(sequence(1)) == TrawlerNet.MaxSeconds, "The slowest net timer")

print(string.format("Boat upgrade checks passed (%d)", checks))
