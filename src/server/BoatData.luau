-- Wallet/boat transactions are pure so the same rules run inside UpdateAsync and tests.
local BoatData = {}
local AnglerData = if script then require(script.Parent.AnglerData) else require("./AnglerData")
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
	Angler: any,
}

function BoatData.decode(raw: any): Profile
	if raw == nil then
		return { Version = 1, Cash = 0, OwnedBoats = {}, OwnedRods = {}, Angler = AnglerData.decode(nil) }
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
	local profile = table.clone(raw)
	profile.OwnedBoats = table.clone(raw.OwnedBoats)
	profile.OwnedRods = table.clone(raw.OwnedRods or {})
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

return BoatData
