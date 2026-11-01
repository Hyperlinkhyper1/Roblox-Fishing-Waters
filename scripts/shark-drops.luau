-- Deterministic reward boundaries and full-inventory persistence checks.
local Drops = require("../src/shared/SharkDrops")
local Data = require("../src/server/AnglerData")
local expected = {
	{ 1, 60, "SharkMeat" },
	{ 61, 80, "SharkFin" },
	{ 81, 92, "SharkTail" },
	{ 93, 97, "SharkHead" },
	{ 98, 100, "GreatWhiteTooth" },
}
for _, tier in expected do
	for roll = tier[1], tier[2] do
		local rng = {
			NextInteger = function(_, minimum, maximum)
				return if maximum == 5 then 2 else roll
			end,
		}
		local drops = Drops.roll(rng)
		assert(#drops == 2 and drops[1].FishId == tier[3] and drops[2].FishId == tier[3])
	end
end
local maximum = Drops.roll({
	NextInteger = function(_, _, max)
		return max
	end,
})
assert(#maximum == 5 and maximum[5].FishId == "GreatWhiteTooth")
local species = {}
for _, entry in Drops.Table do
	species[entry.FishId] = { AverageKg = 1, RarityDenominator = 2, BaseValue = 10, Shapes = { Normal = { "#" } } }
end
local before = Data.decode(nil)
local after, overflow = Data.recordSharkDrops(
	before,
	{ "SharkMeat", "SharkFin", "SharkTail", "SharkHead", "GreatWhiteTooth" },
	123,
	species,
	{ Hold = { "#" } }
)
assert(overflow and after.Hand.FishId == "SharkMeat" and #after.Backpack == 1 and #after.Storage == 3)
assert(after.Backpack[1].Fish.FishId == "SharkFin" and after.Storage[3].FishId == "GreatWhiteTooth")
assert(not before.Hand and #before.Backpack == 0 and #before.Storage == 0)
local loaded = Data.decode(after)
assert(#loaded.Storage == 3 and loaded.Storage[1].CaughtAt == 123)
loaded.Hand = nil
local recovered = Data.takeStored(loaded)
assert(recovered.Hand.FishId == "SharkTail" and #recovered.Storage == 2)
print("Shark drop weights, count, overflow and saved recovery passed")
