-- Wallet/boat transactions are pure so the same rules run inside UpdateAsync and tests.
local BoatData = {}
local BobberSkins = if script
	then require(game:GetService("ReplicatedStorage").Shared.BobberSkins)
	else require("../shared/BobberSkins")
local AnglerData = if script then require(script.Parent.AnglerData) else require("./AnglerData")
local RodUpgrades = if script
	then require(game:GetService("ReplicatedStorage").Shared.RodUpgrades)
	else require("../shared/RodUpgrades")
local RodSkins = if script
	then require(game:GetService("ReplicatedStorage").Shared.RodSkins)
	else require("../shared/RodSkins")
local BoatCatalog = if script
	then require(game:GetService("ReplicatedStorage").Shared.BoatCatalog)
	else require("../shared/BoatCatalog")

BoatData.PRICE = BoatCatalog.Rowboat.Price

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
	RodSkins: { [string]: number },
	RodSkinCopies: { { SkinId: string, Serial: number } },
	NextRodSkinSerial: { [string]: number },
	EquippedRodSkin: string?,
	EquippedRodSkinSerial: number?,
	GroupRodClaimed: boolean?,
	BobberSkins: { [string]: number },
	EquippedBobberSkin: string?,
	Angler: any,
}

function BoatData.decode(raw: any): Profile
	if raw == nil then
		return {
			Version = 1,
			Cash = 0,
			OwnedBoats = {},
			OwnedRods = { StarterRod = true },
			RodUpgrades = {},
			RodSkins = {},
			RodSkinCopies = {},
			NextRodSkinSerial = {},
			BobberSkins = {},
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
	-- Skin counts are copies won from crates. Skins no longer in the catalog are
	-- dropped rather than failing the whole save.
	assert(raw.RodSkins == nil or type(raw.RodSkins) == "table", "Invalid rod skins")
	for id, count in raw.RodSkins or {} do
		assert(type(id) == "string" and type(count) == "number" and count % 1 == 0 and count >= 0, "Invalid rod skin")
	end
	assert(raw.EquippedRodSkin == nil or type(raw.EquippedRodSkin) == "string", "Invalid equipped rod skin")
	local profile = table.clone(raw)
	assert(raw.GroupRodClaimed == nil or type(raw.GroupRodClaimed) == "boolean", "Invalid group reward claim")
	profile.OwnedBoats = table.clone(raw.OwnedBoats)
	profile.OwnedRods = table.clone(raw.OwnedRods or {})
	-- Every angler starts with a rod, including profiles saved before this default.
	profile.OwnedRods.StarterRod = true
	profile.RodUpgrades = {}
	for stat, level in raw.RodUpgrades or {} do
		profile.RodUpgrades[stat] = math.min(level, RodUpgrades.Stats[stat].MaxLevel)
	end
	profile.RodSkins = {}
	for id, count in raw.RodSkins or {} do
		if count > 0 and RodSkins.valid(id) then
			profile.RodSkins[id] = count
		end
	end
	-- Each skin has its own sequence. Numeric counters belong to the old shared
	-- sequence; migrate those copies in award order and preserve the selected copy.
	local savedCounts = profile.RodSkins
	profile.RodSkins, profile.RodSkinCopies, profile.NextRodSkinSerial = {}, {}, {}
	local perSkinSerials = type(raw.NextRodSkinSerial) == "table"
	if perSkinSerials then
		for id, nextSerial in raw.NextRodSkinSerial do
			assert(
				type(id) == "string"
					and type(nextSerial) == "number"
					and nextSerial >= 1
					and nextSerial < 2 ^ 53
					and nextSerial % 1 == 0,
				"Invalid skin serial counter"
			)
			profile.NextRodSkinSerial[id] = nextSerial
		end
	elseif raw.NextRodSkinSerial ~= nil then
		assert(
			type(raw.NextRodSkinSerial) == "number"
				and raw.NextRodSkinSerial >= 1
				and raw.NextRodSkinSerial < 2 ^ 53
				and raw.NextRodSkinSerial % 1 == 0,
			"Invalid legacy skin serial counter"
		)
	end
	assert(
		raw.EquippedRodSkinSerial == nil
			or (
				type(raw.EquippedRodSkinSerial) == "number"
				and raw.EquippedRodSkinSerial >= 1
				and raw.EquippedRodSkinSerial % 1 == 0
			),
		"Invalid equipped skin serial"
	)
	profile.EquippedRodSkin, profile.EquippedRodSkinSerial = nil, nil
	local function addCopy(id, serial, originalSerial)
		if not RodSkins.valid(id) then
			return
		end
		table.insert(profile.RodSkinCopies, { SkinId = id, Serial = serial })
		profile.RodSkins[id] = (profile.RodSkins[id] or 0) + 1
		if
			profile.EquippedRodSkin == nil
			and id == raw.EquippedRodSkin
			and (raw.EquippedRodSkinSerial == nil or originalSerial == raw.EquippedRodSkinSerial)
		then
			profile.EquippedRodSkin, profile.EquippedRodSkinSerial = id, serial
		end
	end
	if raw.RodSkinCopies == nil then
		local ids = {}
		for id in savedCounts do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local nextSerial = profile.NextRodSkinSerial[id] or 1
			for _ = 1, savedCounts[id] do
				addCopy(id, nextSerial, nextSerial)
				nextSerial += 1
			end
			profile.NextRodSkinSerial[id] = nextSerial
		end
	else
		assert(type(raw.RodSkinCopies) == "table", "Invalid skin copies")
		local seen, copies = {}, {}
		for index, copy in raw.RodSkinCopies do
			assert(
				type(index) == "number" and index >= 1 and index % 1 == 0 and index <= #raw.RodSkinCopies,
				"Invalid skin copy index"
			)
			assert(type(copy) == "table" and type(copy.SkinId) == "string", "Invalid skin copy")
			local serial = copy.Serial
			local skinSeen = seen[copy.SkinId] or {}
			assert(
				type(serial) == "number"
					and serial >= 1
					and serial < 2 ^ 53 - 1
					and serial % 1 == 0
					and not skinSeen[serial],
				"Invalid skin serial"
			)
			skinSeen[serial], seen[copy.SkinId] = true, skinSeen
			table.insert(copies, copy)
		end
		if not perSkinSerials then
			table.sort(copies, function(a, b)
				return a.Serial < b.Serial
			end)
		end
		for _, copy in copies do
			local id = copy.SkinId
			local nextSerial = profile.NextRodSkinSerial[id] or 1
			local serial = if perSkinSerials then copy.Serial else nextSerial
			profile.NextRodSkinSerial[id] = math.max(nextSerial, serial + 1)
			addCopy(id, serial, copy.Serial)
		end
	end
	-- Old profiles start with the original float. Unknown retired skins are ignored.
	assert(raw.BobberSkins == nil or type(raw.BobberSkins) == "table", "Invalid bobber inventory")
	profile.BobberSkins = {}
	for id, count in raw.BobberSkins or {} do
		assert(
			type(id) == "string" and type(count) == "number" and count >= 0 and count < 2 ^ 53 and count % 1 == 0,
			"Invalid bobber count"
		)
		if count > 0 and BobberSkins.valid(id) then
			profile.BobberSkins[id] = count
		end
	end
	assert(raw.EquippedBobberSkin == nil or type(raw.EquippedBobberSkin) == "string", "Invalid equipped bobber")
	profile.EquippedBobberSkin = if BobberSkins.valid(raw.EquippedBobberSkin)
			and profile.BobberSkins[raw.EquippedBobberSkin]
		then raw.EquippedBobberSkin
		else nil
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

-- Mutates a decoded profile in place: pays for one crate and adds the skin the
-- caller already rolled (RodSkins.roll), so UpdateAsync retries award the same skin.
function BoatData.openRodCrate(profile: Profile, crateId: string, skinId: string): (string, number?)
	local crate = RodSkins.Crates[crateId]
	if not crate or not table.find(crate.Skins, skinId) then
		return "UnknownCrate"
	end
	if not profile.OwnedRods.StarterRod then
		return "NoRod"
	end
	if profile.Cash < crate.Price then
		return "InsufficientFunds"
	end
	local serial = profile.NextRodSkinSerial[skinId] or 1
	assert(serial < 2 ^ 53 - 1, "Skin serial limit reached")
	profile.Cash -= crate.Price
	profile.Angler.Stats.CoinsSpent += crate.Price
	profile.RodSkins[skinId] = (profile.RodSkins[skinId] or 0) + 1
	table.insert(profile.RodSkinCopies, { SkinId = skinId, Serial = serial })
	profile.NextRodSkinSerial[skinId] = serial + 1
	return "Opened", serial
end

-- Membership is verified by FishingService. The receipt and serial are committed
-- together in the existing wallet transaction, including UpdateAsync retries.
function BoatData.claimGroupRod(profile: Profile): (string, number?)
	local id = RodSkins.GroupReward
	if profile.GroupRodClaimed then
		return "AlreadyClaimed"
	end
	for _, copy in profile.RodSkinCopies do
		if copy.SkinId == id then
			profile.GroupRodClaimed = true
			return "AlreadyClaimed", copy.Serial
		end
	end
	local serial = profile.NextRodSkinSerial[id] or 1
	assert(serial < 2 ^ 53 - 1, "Skin serial limit reached")
	profile.RodSkins[id] = (profile.RodSkins[id] or 0) + 1
	table.insert(profile.RodSkinCopies, { SkinId = id, Serial = serial })
	profile.NextRodSkinSerial[id] = serial + 1
	profile.GroupRodClaimed = true
	return "Claimed", serial
end

-- Mutates a decoded profile in place: nil puts the plain starter rod back on.
function BoatData.equipRodSkin(profile: Profile, skinId: string?, serial: number?): string
	if skinId ~= nil and not RodSkins.valid(skinId) then
		return "UnknownSkin"
	end
	if skinId ~= nil and not profile.RodSkins[skinId] then
		return "NotOwned"
	end
	if skinId == nil then
		profile.EquippedRodSkin, profile.EquippedRodSkinSerial = nil, nil
		return "Equipped"
	end
	for _, copy in profile.RodSkinCopies do
		if copy.SkinId == skinId and (serial == nil or copy.Serial == serial) then
			profile.EquippedRodSkin, profile.EquippedRodSkinSerial = skinId, copy.Serial
			return "Equipped"
		end
	end
	return "NotOwned"
end

function BoatData.openBobberCrate(profile: Profile, crateId: string, skinId: string): string
	local crate = BobberSkins.Crates[crateId]
	if not crate or not table.find(crate.Skins, skinId) then
		return "UnknownCrate"
	end
	if not profile.OwnedRods.StarterRod then
		return "NoRod"
	end
	if profile.Cash < crate.Price then
		return "InsufficientFunds"
	end
	profile.Cash -= crate.Price
	profile.Angler.Stats.CoinsSpent += crate.Price
	profile.BobberSkins[skinId] = (profile.BobberSkins[skinId] or 0) + 1
	return "Opened"
end

function BoatData.equipBobberSkin(profile: Profile, skinId: string?): string
	if skinId ~= nil and not BobberSkins.valid(skinId) then
		return "UnknownSkin"
	end
	if skinId ~= nil and not profile.BobberSkins[skinId] then
		return "NotOwned"
	end
	profile.EquippedBobberSkin = skinId
	return "Equipped"
end

return BoatData
