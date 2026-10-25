-- Wallet/boat transactions are pure so the same rules run inside UpdateAsync and tests.
local BoatData = {}
local AnglerData = if script then require(script.Parent.AnglerData) else require("./AnglerData")
local RodUpgrades = if script
	then require(game:GetService("ReplicatedStorage").Shared.RodUpgrades)
	else require("../shared/RodUpgrades")
local BoatCatalog = if script
	then require(game:GetService("ReplicatedStorage").Shared.BoatCatalog)
	else require("../shared/BoatCatalog")

BoatData.PRICE = BoatCatalog.Rowboat.Price
BoatData.ROD_PRICE = 0

function BoatData.trackProgress(previous, current, now)
	current.Angler = AnglerData.trackProgress(previous.Angler, current.Angler, now)
end

function BoatData.leaderboardScores(profile, now)
	return AnglerData.scores(profile.Angler, now)
end

function BoatData.levelProgress(profile)
	return AnglerData.levelProgress(profile.Angler.Stats.TotalXP)
end

export type Profile = {
	Version: number,
	Cash: number,
	OwnedBoats: { [string]: boolean },
	OwnedRods: { [string]: boolean },
	RodUpgrades: { [string]: number },
	Angler: any,
}

function BoatData.decode(raw: any): Profile
	if raw == nil then
		return {
			Version = 1,
			Cash = 0,
			OwnedBoats = {},
			OwnedRods = {},
			RodUpgrades = {},
			Angler = AnglerData.decode(nil),
		}
	end
	assert(type(raw) == "table" and raw.Version == 1, "Unsupported boating data")
	assert(
		type(raw.Cash) == "number" and raw.Cash >= 0 and raw.Cash < 2 ^ 53 and raw.Cash % 1 == 0,
		"Invalid wallet balance"
	)
	assert(type(raw.OwnedBoats) == "table", "Invalid boat inventory")
	for id, owned in raw.OwnedBoats do
		assert(type(id) == "string" and type(owned) == "boolean", "Invalid boat ownership")
	end
	-- Existing wallet records predate rods. Missing inventory migrates in memory;
	-- malformed saved inventory is rejected rather than silently overwritten.
	assert(raw.OwnedRods == nil or type(raw.OwnedRods) == "table", "Invalid rod inventory")
	for id, owned in raw.OwnedRods or {} do
		assert(type(id) == "string" and type(owned) == "boolean", "Invalid rod ownership")
	end
	assert(raw.RodUpgrades == nil or type(raw.RodUpgrades) == "table", "Invalid rod upgrades")
	for stat, level in raw.RodUpgrades or {} do
		assert(
			RodUpgrades.valid(stat) and type(level) == "number" and level % 1 == 0 and level >= 0,
			"Invalid rod upgrade level"
		)
	end
	local profile = table.clone(raw)
	profile.OwnedBoats = table.clone(raw.OwnedBoats)
	profile.OwnedRods = table.clone(raw.OwnedRods or {})
	profile.RodUpgrades = {}
	for stat, level in raw.RodUpgrades or {} do
		profile.RodUpgrades[stat] = math.min(level, RodUpgrades.Stats[stat].MaxLevel)
	end
	profile.Angler = AnglerData.decode(raw.Angler)
	return profile
end

function BoatData.purchase(raw: any, boatId: string?): (Profile, string)
	local profile = BoatData.decode(raw)
	local id = boatId or "Rowboat"
	local spec = BoatCatalog[id]
	if not spec then
		return profile, "UnknownBoat"
	end
	if profile.OwnedBoats[id] then
		return profile, "AlreadyOwned"
	end
	if profile.Cash < spec.Price then
		return profile, "InsufficientFunds"
	end
	profile.Cash -= spec.Price
	profile.Angler.Stats.CoinsSpent += spec.Price
	profile.OwnedBoats[id] = true
	return profile, "Purchased"
end

function BoatData.purchaseRod(raw: any): (Profile, string)
	local profile = BoatData.decode(raw)
	if profile.OwnedRods.StarterRod then
		return profile, "AlreadyOwned"
	end
	if profile.Cash < BoatData.ROD_PRICE then
		return profile, "InsufficientFunds"
	end
	profile.Cash -= BoatData.ROD_PRICE
	profile.Angler.Stats.CoinsSpent += BoatData.ROD_PRICE
	profile.OwnedRods.StarterRod = true
	return profile, "Purchased"
end

-- Mutates a decoded profile in place: buys the next level of one rod stat.
function BoatData.upgradeRod(profile: Profile, stat: string): string
	if not RodUpgrades.valid(stat) then
		return "UnknownUpgrade"
	end
	local level = RodUpgrades.level(profile.RodUpgrades, stat)
	local price = RodUpgrades.price(stat, level)
	if not price then
		return "Maxed"
	end
	if not profile.OwnedRods.StarterRod then
		return "NoRod"
	end
	if profile.Cash < price then
		return "InsufficientFunds"
	end
	profile.Cash -= price
	profile.Angler.Stats.CoinsSpent += price
	profile.RodUpgrades[stat] = level + 1
	return "Upgraded"
end

return BoatData
