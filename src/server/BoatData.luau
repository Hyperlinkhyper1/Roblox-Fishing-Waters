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
local SpearSkins = if script
	then require(game:GetService("ReplicatedStorage").Shared.SpearSkins)
	else require("../shared/SpearSkins")
local Bait = if script
	then require(game:GetService("ReplicatedStorage").Shared.Bait)
	else require("../shared/Bait")
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
	OwnedSpears: { [string]: boolean },
	SpearSkinCopies: { { SkinId: string, Serial: number, Wear: number } },
	EquippedSpearSkin: string?,
	EquippedSpearSkinSerial: number?,
	RodUpgrades: { [string]: number },
	RodSkins: { [string]: number },
	RodSkinCopies: { { SkinId: string, Serial: number, Wear: number } },
	RodCrates: { [string]: number },
	NextRodSkinSerial: { [string]: number },
	RodSerialScope: string?,
	EquippedRodSkin: string?,
	EquippedRodSkinSerial: number?,
	GroupRodClaimed: boolean?,
	BobberSkins: { [string]: number },
	EquippedBobberSkin: string?,
	BaitCrates: number,
	Bait: { [string]: number },
	EquippedBait: string?,
	Angler: any,
}

function BoatData.decode(raw: any): Profile
	if raw == nil then
		return {
			Version = 1,
			Cash = 0,
			OwnedBoats = { Rowboat = true },
			OwnedRods = { StarterRod = true },
			OwnedSpears = {},
			SpearSkinCopies = {},
			RodUpgrades = {},
			RodSkins = {},
			RodSkinCopies = {},
			RodCrates = {},
			NextRodSkinSerial = {},
			RodSerialScope = "GlobalV1",
			BobberSkins = {},
			BaitCrates = 0,
			Bait = {},
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
	assert(raw.OwnedSpears == nil or type(raw.OwnedSpears) == "table", "Invalid spear inventory")
	for id, owned in raw.OwnedSpears or {} do
		assert(type(id) == "string" and type(owned) == "boolean", "Invalid spear ownership")
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
	assert(raw.RodSerialScope == nil or raw.RodSerialScope == "GlobalV1", "Unsupported rod serial scope")
	assert(raw.GroupRodClaimed == nil or type(raw.GroupRodClaimed) == "boolean", "Invalid group reward claim")
	profile.OwnedBoats = table.clone(raw.OwnedBoats)
	profile.OwnedRods = table.clone(raw.OwnedRods or {})
	profile.OwnedSpears = table.clone(raw.OwnedSpears or {})
	assert(raw.SpearSkinCopies == nil or type(raw.SpearSkinCopies) == "table", "Invalid spear skin copies")
	assert(raw.EquippedSpearSkin == nil or type(raw.EquippedSpearSkin) == "string", "Invalid equipped spear skin")
	assert(
		raw.EquippedSpearSkinSerial == nil
			or (
				type(raw.EquippedSpearSkinSerial) == "number"
				and raw.EquippedSpearSkinSerial >= 1
				and raw.EquippedSpearSkinSerial < 2 ^ 53 - 1
				and raw.EquippedSpearSkinSerial % 1 == 0
			),
		"Invalid equipped spear serial"
	)
	profile.SpearSkinCopies = {}
	profile.EquippedSpearSkin, profile.EquippedSpearSkinSerial = nil, nil
	local spearSerials = {}
	for index, copy in raw.SpearSkinCopies or {} do
		assert(
			type(index) == "number" and index >= 1 and index % 1 == 0 and index <= #raw.SpearSkinCopies,
			"Invalid spear skin index"
		)
		assert(type(copy) == "table" and type(copy.SkinId) == "string", "Invalid spear skin copy")
		assert(
			type(copy.Serial) == "number" and copy.Serial >= 1 and copy.Serial < 2 ^ 53 - 1 and copy.Serial % 1 == 0,
			"Invalid spear skin serial"
		)
		assert(SpearSkins.validWear(copy.Wear), "Invalid spear skin wear")
		local serials = spearSerials[copy.SkinId] or {}
		assert(not serials[copy.Serial], "Duplicate spear skin serial")
		serials[copy.Serial], spearSerials[copy.SkinId] = true, serials
		if SpearSkins.valid(copy.SkinId) then
			table.insert(profile.SpearSkinCopies, { SkinId = copy.SkinId, Serial = copy.Serial, Wear = copy.Wear })
			if copy.SkinId == raw.EquippedSpearSkin and copy.Serial == raw.EquippedSpearSkinSerial then
				profile.EquippedSpearSkin, profile.EquippedSpearSkinSerial = copy.SkinId, copy.Serial
			end
		end
	end
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
	-- Normalize historical per-player counters for RodSerials.migrate. Numbers
	-- already in the global format survive decoding without being renumbered.
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
	local function addCopy(id, serial, originalSerial, wear)
		if not RodSkins.valid(id) then
			return
		end
		table.insert(profile.RodSkinCopies, { SkinId = id, Serial = serial, Wear = wear or RodSkins.DefaultWear })
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
			assert(copy.Wear == nil or RodSkins.validWear(copy.Wear), "Invalid skin wear")
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
			addCopy(id, serial, copy.Serial, copy.Wear)
		end
	end
	assert(raw.RodCrates == nil or type(raw.RodCrates) == "table", "Invalid rod crates")
	profile.RodCrates = {}
	for id, count in raw.RodCrates or {} do
		assert(
			type(id) == "string" and type(count) == "number" and count >= 0 and count < 2 ^ 53 and count % 1 == 0,
			"Invalid rod crate count"
		)
		if count > 0 then
			profile.RodCrates[id] = count
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
	-- Profiles from before bait start with an empty tin.
	assert(
		raw.BaitCrates == nil
			or (
				type(raw.BaitCrates) == "number"
				and raw.BaitCrates >= 0
				and raw.BaitCrates < 2 ^ 53
				and raw.BaitCrates % 1 == 0
			),
		"Invalid bait crate count"
	)
	profile.BaitCrates = raw.BaitCrates or 0
	assert(raw.Bait == nil or type(raw.Bait) == "table", "Invalid bait inventory")
	profile.Bait = {}
	for id, count in raw.Bait or {} do
		assert(
			type(id) == "string" and type(count) == "number" and count >= 0 and count < 2 ^ 53 and count % 1 == 0,
			"Invalid bait count"
		)
		if count > 0 and Bait.valid(id) then
			profile.Bait[id] = count
		end
	end
	assert(raw.EquippedBait == nil or type(raw.EquippedBait) == "string", "Invalid equipped bait")
	profile.EquippedBait = if Bait.valid(raw.EquippedBait) and profile.Bait[raw.EquippedBait]
		then raw.EquippedBait
		else nil
	-- Saves from before branches were added have none: they are fishing companies.
	-- (Shared.Branches holds the catalog; test harnesses inline this file, so the
	-- shape check lives here.)
	assert(raw.Branches == nil or type(raw.Branches) == "table", "Invalid company branches")
	if raw.Branches ~= nil then
		local branches = {}
		for id, owned in raw.Branches do
			assert(type(id) == "string" and #id <= 32 and type(owned) == "boolean", "Invalid company branch")
			if owned then
				branches[id] = true
			end
		end
		profile.Branches = if next(branches) then branches else nil
	end
	assert(raw.Cafe == nil or type(raw.Cafe) == "table", "Invalid café progress")
	if raw.Cafe ~= nil then
		local served = raw.Cafe.Served or 0
		assert(type(served) == "number" and served >= 0 and served < 2 ^ 53 and served % 1 == 0, "Invalid café progress")
		-- Café tour progress (Shared.CafeTutorial). Cafés that served coffee before the tour
		-- existed start with it finished; /tutorial replays it.
		local step, count = raw.Cafe.TutorialStep, raw.Cafe.TutorialCount or 0
		local done = if step == nil then served > 0 else raw.Cafe.TutorialDone == true
		step = step or 1
		assert(type(step) == "number" and step >= 1 and step < 2 ^ 31 and step % 1 == 0, "Invalid café tutorial step")
		assert(type(count) == "number" and count >= 0 and count < 2 ^ 31 and count % 1 == 0, "Invalid café tutorial count")
		profile.Cafe = {
			Served = served,
			TutorialStep = step,
			TutorialDone = done,
			TutorialCount = count,
			TutorialRewarded = raw.Cafe.TutorialRewarded == true,
		}
	end
	profile.Angler = AnglerData.decode(raw.Angler)
	return profile
end

-- Boats with a RequiresPath stay off sale until that business path is unlocked.
-- Reads the saved path table directly (see Shared.Paths.state for its shape).
function BoatData.pathLocked(profile: Profile, boatId: string): boolean
	local spec = BoatCatalog[boatId]
	if not spec or not spec.RequiresPath then
		return false
	end
	local paths = profile.Angler and profile.Angler.Paths
	return not (paths and paths.Unlocked and paths.Unlocked[spec.RequiresPath] == true)
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
	if BoatData.pathLocked(profile, id) then
		return profile, "Locked"
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

-- Separate atomic transactions preserve purchased crates across sessions.
function BoatData.buyRodCrates(profile: Profile, crateId: string, count: number): string
	local crate = RodSkins.Crates[crateId]
	if not crate then
		return "UnknownCrate"
	end
	if count ~= 1 and count ~= 3 and count ~= 10 then
		return "InvalidCount"
	end
	if not profile.OwnedRods.StarterRod then
		return "NoRod"
	end
	local price = crate.Price * count
	if profile.Cash < price then
		return "InsufficientFunds"
	end
	profile.Cash -= price
	profile.Angler.Stats.CoinsSpent += price
	profile.RodCrates[crateId] = (profile.RodCrates[crateId] or 0) + count
	return "Purchased"
end

-- A rod bought outright (Pirate Cove's trader): one copy of `skinId` with a reserved global serial.
-- Call with no serial to check affordability only.
function BoatData.buyRodSkin(profile: Profile, skinId: string, price: number, wear: number, serial: number?): string
	if not RodSkins.valid(skinId) then
		return "UnknownRod"
	end
	if not profile.OwnedRods.StarterRod then
		return "NoRod"
	end
	if profile.Cash < price then
		return "InsufficientFunds"
	end
	if serial == nil then
		return "Purchased"
	end
	assert(RodSkins.validWear(wear), "Invalid skin wear")
	assert(type(serial) == "number" and serial >= 1 and serial < 2 ^ 53 - 1 and serial % 1 == 0, "Missing global skin serial")
	for _, copy in profile.RodSkinCopies do
		assert(copy.SkinId ~= skinId or copy.Serial ~= serial, "Skin serial already owned")
	end
	profile.Cash -= price
	profile.Angler.Stats.CoinsSpent += price
	profile.RodSkins[skinId] = (profile.RodSkins[skinId] or 0) + 1
	table.insert(profile.RodSkinCopies, { SkinId = skinId, Serial = serial, Wear = wear })
	profile.NextRodSkinSerial[skinId] = math.max(profile.NextRodSkinSerial[skinId] or 1, serial + 1)
	return "Purchased"
end

function BoatData.openOwnedRodCrate(
	profile: Profile,
	crateId: string,
	skinId: string,
	serial: number,
	wear: number
): string
	local crate = RodSkins.Crates[crateId]
	if not crate or not table.find(crate.Skins, skinId) then
		return "UnknownCrate"
	end
	if (profile.RodCrates[crateId] or 0) < 1 then
		return "NoCrate"
	end
	assert(RodSkins.validWear(wear), "Invalid skin wear")
	assert(
		type(serial) == "number" and serial >= 1 and serial < 2 ^ 53 - 1 and serial % 1 == 0,
		"Missing global skin serial"
	)
	for _, copy in profile.RodSkinCopies do
		assert(copy.SkinId ~= skinId or copy.Serial ~= serial, "Skin serial already owned")
	end
	profile.RodCrates[crateId] -= 1
	profile.RodSkins[skinId] = (profile.RodSkins[skinId] or 0) + 1
	table.insert(profile.RodSkinCopies, { SkinId = skinId, Serial = serial, Wear = wear })
	profile.NextRodSkinSerial[skinId] = math.max(profile.NextRodSkinSerial[skinId] or 1, serial + 1)
	return "Opened"
end

function BoatData.equippedRodWear(profile: Profile): number
	for _, copy in profile.RodSkinCopies do
		if copy.SkinId == profile.EquippedRodSkin and copy.Serial == profile.EquippedRodSkinSerial then
			return copy.Wear or RodSkins.DefaultWear
		end
	end
	return RodSkins.DefaultWear
end

function BoatData.canOpenRodCrate(profile: Profile, crateId: string, skinId: string): string
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
	return "Opened"
end

-- The server reserves a GLOBAL number before UpdateAsync, then supplies the same
-- number on every retry. Profile counters remain only for decoding older saves.
function BoatData.openRodCrate(profile: Profile, crateId: string, skinId: string, serial: number): (string, number?)
	local outcome = BoatData.canOpenRodCrate(profile, crateId, skinId)
	if outcome ~= "Opened" then
		return outcome
	end
	assert(
		type(serial) == "number" and serial >= 1 and serial < 2 ^ 53 - 1 and serial % 1 == 0,
		"Missing global skin serial"
	)
	for _, copy in profile.RodSkinCopies do
		assert(copy.SkinId ~= skinId or copy.Serial ~= serial, "Skin serial already owned")
	end
	local crate = RodSkins.Crates[crateId]
	profile.Cash -= crate.Price
	profile.Angler.Stats.CoinsSpent += crate.Price
	profile.RodSkins[skinId] = (profile.RodSkins[skinId] or 0) + 1
	table.insert(profile.RodSkinCopies, { SkinId = skinId, Serial = serial })
	profile.NextRodSkinSerial[skinId] = serial + 1
	return "Opened", serial
end

-- Membership is verified by FishingService. The receipt and serial are committed
-- together in the existing wallet transaction, including UpdateAsync retries.
function BoatData.claimGroupRod(profile: Profile, serial: number): (string, number?)
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
	assert(
		type(serial) == "number" and serial >= 1 and serial < 2 ^ 53 - 1 and serial % 1 == 0,
		"Missing global skin serial"
	)
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

-- Rolls and serials are chosen before the transaction so retries award the same copy.
function BoatData.openSpearCrate(
	profile: Profile,
	crateId: string,
	skinId: string,
	serial: number,
	wear: number
): string
	local crate = SpearSkins.Crates[crateId]
	if not crate or not table.find(crate.Skins, skinId) then
		return "UnknownCrate"
	end
	if profile.Cash < crate.Price then
		return "InsufficientFunds"
	end
	assert(
		type(serial) == "number" and serial >= 1 and serial < 2 ^ 53 - 1 and serial % 1 == 0,
		"Invalid spear skin serial"
	)
	assert(SpearSkins.validWear(wear), "Invalid spear wear")
	for _, copy in profile.SpearSkinCopies do
		assert(copy.SkinId ~= skinId or copy.Serial ~= serial, "Spear skin serial already owned")
	end
	profile.Cash -= crate.Price
	profile.Angler.Stats.CoinsSpent += crate.Price
	table.insert(profile.SpearSkinCopies, { SkinId = skinId, Serial = serial, Wear = wear })
	return "Opened"
end

function BoatData.equipSpearSkin(profile: Profile, skinId: string?, serial: number?): string
	if skinId == nil then
		profile.EquippedSpearSkin, profile.EquippedSpearSkinSerial = nil, nil
		return "Equipped"
	end
	if not SpearSkins.valid(skinId) then
		return "UnknownSkin"
	end
	for _, copy in profile.SpearSkinCopies do
		if copy.SkinId == skinId and (serial == nil or copy.Serial == serial) then
			profile.EquippedSpearSkin, profile.EquippedSpearSkinSerial = skinId, copy.Serial
			return "Equipped"
		end
	end
	return "NotOwned"
end

function BoatData.equippedSpearWear(profile: Profile): number
	for _, copy in profile.SpearSkinCopies do
		if copy.SkinId == profile.EquippedSpearSkin and copy.Serial == profile.EquippedSpearSkinSerial then
			return copy.Wear
		end
	end
	return SpearSkins.DefaultWear
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

function BoatData.buyBaitCrates(profile: Profile, count: number): string
	if not Bait.validBuyCount(count) then
		return "InvalidCount"
	end
	local price = Bait.Crate.Price * count
	if profile.Cash < price then
		return "InsufficientFunds"
	end
	profile.Cash -= price
	profile.Angler.Stats.CoinsSpent += price
	profile.BaitCrates += count
	return "Purchased"
end

-- Opens one owned crate holding `amount` of `baitId`, rolled by the caller so
-- save retries award the same bait. An empty hook takes the new bait.
function BoatData.openBaitCrate(profile: Profile, baitId: string, amount: number): string
	if not Bait.valid(baitId) then
		return "UnknownBait"
	end
	if profile.BaitCrates < 1 then
		return "NoCrate"
	end
	assert(type(amount) == "number" and amount >= 1 and amount % 1 == 0, "Invalid bait amount")
	profile.BaitCrates -= 1
	profile.Bait[baitId] = (profile.Bait[baitId] or 0) + amount
	if profile.EquippedBait == nil then
		profile.EquippedBait = baitId
	end
	return "Opened"
end

function BoatData.equipBait(profile: Profile, baitId: string?): string
	if baitId ~= nil and not Bait.valid(baitId) then
		return "UnknownBait"
	end
	if baitId ~= nil and (profile.Bait[baitId] or 0) < 1 then
		return "NotOwned"
	end
	profile.EquippedBait = baitId
	return "Equipped"
end

-- One bait is used up per catch reeled in. Running out empties the hook.
function BoatData.consumeBait(profile: Profile, baitId: string): string
	local count = profile.Bait[baitId] or 0
	if count < 1 then
		return "NoBait"
	end
	profile.Bait[baitId] = if count > 1 then count - 1 else nil
	if count == 1 and profile.EquippedBait == baitId then
		profile.EquippedBait = nil
	end
	return "Consumed"
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
