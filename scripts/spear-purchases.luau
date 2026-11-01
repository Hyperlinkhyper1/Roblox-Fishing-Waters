-- Pure purchase and migration checks; does not exercise Studio replication.
local BoatData = require("../src/server/BoatData")
local Spears = require("../src/shared/Spears")
local profile = BoatData.decode({ Version = 1, Cash = Spears.PRICE - 1, OwnedBoats = {} })
assert(next(profile.OwnedSpears) == nil, "Older profiles should migrate without owning a spear")
assert(Spears.buyProblem(profile) ~= nil, "Insufficient funds must be rejected")
profile.Cash = Spears.PRICE + 10
local spent = profile.Angler.Stats.CoinsSpent
Spears.buy(profile)
assert(profile.Cash == 10 and profile.OwnedSpears.BasicSpear, "Purchase should deduct price and grant spear")
assert(profile.Angler.Stats.CoinsSpent == spent + Spears.PRICE, "Purchase should count toward spending")
assert(Spears.buyProblem(profile) ~= nil, "A player cannot buy a second permanent spear")
local restored = BoatData.decode(profile)
assert(restored.OwnedSpears.BasicSpear, "Spear ownership must survive decoding")
assert(
	not pcall(BoatData.decode, { Version = 1, Cash = 0, OwnedBoats = {}, OwnedSpears = { BasicSpear = 1 } }),
	"Malformed ownership must be rejected"
)
print("Spear purchase checks passed")
