-- Pirate Cove checks: the crew roster and outfits, every quest is possible (its fish exist and
-- bite somewhere), the rod trader's stock, the galley's 15-a-day limit, quest deliveries and the
-- saved shape in AnglerData/BoatData. No Roblox runtime.
-- Run: lute run scripts/pirate-cove.luau
local fs = require("@lute/fs")
local luau = require("@lute/luau")
local BoatData = require("../src/server/BoatData")
local Data = require("../src/server/AnglerData")
local Cove = require("../src/shared/PirateCove")
local RodSkins = require("../src/shared/RodSkins")
local FishSpecies = require("./fish-species")

local function read(path: string): string
	local file = fs.open(path, "r")
	local source = fs.read(file)
	fs.close(file)
	return source
end

local Color3 = {
	fromRGB = function(...)
		return { ... }
	end,
}
local Catalog = luau.load(
	luau.compile(FishSpecies.inline(read("src/shared/AnglerCatalog.luau"))),
	"AnglerCatalog",
	FishSpecies.env({ Color3 = Color3 })
)()

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- Every source that ships with the cove at least compiles.
for _, path in
	{
		"src/shared/PirateCove.luau",
		"src/server/Map/PirateCove.luau",
		"src/server/PirateCoveService.luau",
		"src/client/PirateCove.luau",
	}
do
	check(pcall(luau.load, luau.compile(read(path)), path, {}), path .. " does not compile")
end

-- Roster: everyone in the order is defined once, dressed in pieces GuideCostume can build.
local costumeKinds = {}
for kind in string.gmatch(read("src/server/GuideCostume.luau"), "function KINDS%.(%w+)") do
	costumeKinds[kind] = true
end
local seen = {}
local kinds = { Quests = 0, Shop = 0, Buyer = 0, Lore = 0 }
for _, id in Cove.Order do
	local npc = Cove.Npcs[id]
	check(npc ~= nil, "Unknown crew member in order: " .. id)
	check(not seen[id], "Crew member listed twice: " .. id)
	seen[id] = true
	check(
		type(npc.Name) == "string" and type(npc.Title) == "string" and type(npc.Greeting) == "string",
		id .. " needs a name, title and greeting"
	)
	check(kinds[npc.Kind] ~= nil, id .. " has unknown kind " .. tostring(npc.Kind))
	kinds[npc.Kind] += 1
	check(type(npc.Spot) == "string" or (type(npc.Spot) == "table" and #npc.Spot == 2), id .. " needs a spot")
	if npc.Outfit.Catalog then
		check(type(npc.Outfit.Shirt) == "number" and type(npc.Outfit.Pants) == "number", id .. " needs catalog clothes")
		check(npc.Outfit.Hat == nil or type(npc.Outfit.Hat) == "number", id .. " has a bad catalog hat")
		check(npc.Outfit.Beard == nil or type(npc.Outfit.Beard) == "number", id .. " has a bad catalog beard")
	else
		for _, spec in npc.Outfit.Pieces or {} do
			check(costumeKinds[spec.Kind], id .. " wears an unknown piece " .. tostring(spec.Kind))
		end
	end
	if npc.Kind == "Quests" then
		check(Cove.Quests[id] and #Cove.Quests[id] > 0, id .. " gives quests but has none")
	elseif npc.Kind == "Lore" then
		check(type(npc.Lore) == "table" and #npc.Lore > 0, id .. " has no lore to tell")
	end
end
for id in Cove.Npcs do
	check(seen[id], "Crew member missing from order: " .. id)
end
check(
	kinds.Shop == 1 and kinds.Buyer == 1 and kinds.Lore >= 1 and kinds.Quests >= 5,
	"The cove has one rod trader, one fish buyer, a storyteller and plenty of quest givers"
)
-- Named spots are anchors the island builder sets.
local builder = read("src/server/Map/PirateCove.luau")
for id, npc in Cove.Npcs do
	if type(npc.Spot) == "string" then
		local named = string.find(builder, 'id = "' .. npc.Spot .. '"', 1, true)
			or string.find(builder, "anchors." .. npc.Spot .. " =", 1, true)
		check(named, id .. " stands at " .. npc.Spot .. ", which the island never sets")
	end
end
-- Numeric spots are far enough apart that nobody stands in someone else.
for a, first in Cove.Npcs do
	for b, second in Cove.Npcs do
		if a < b and type(first.Spot) == "table" and type(second.Spot) == "table" then
			local dx, dz = first.Spot[1] - second.Spot[1], first.Spot[2] - second.Spot[2]
			check(math.sqrt(dx * dx + dz * dz) > 6, a .. " and " .. b .. " stand on top of each other")
		end
	end
end

-- Quests: each is possible. Delivered fish exist and bite in some pool (junk bites everywhere).
local biting = {}
for _, pool in Catalog.Pools do
	for _, id in pool.Fish do
		biting[id] = true
	end
	for _, id in pool.Junk or {} do
		biting[id] = true
	end
end
for npcId, chain in Cove.Quests do
	check(Cove.Npcs[npcId] and Cove.Npcs[npcId].Kind == "Quests", npcId .. " has quests but isn't a quest giver")
	for index, quest in chain do
		local where = npcId .. " quest " .. index
		check(
			type(quest.Title) == "string" and type(quest.Offer) == "string" and type(quest.Done) == "string",
			where .. " needs text"
		)
		check(type(quest.Cash) == "number" and quest.Cash > 0 and quest.Cash % 1 == 0, where .. " needs a cash reward")
		check(type(quest.XP) == "number" and quest.XP > 0 and quest.XP % 1 == 0, where .. " needs an XP reward")
		if quest.Kind == "Catch" then
			check(type(quest.Count) == "number" and quest.Count > 0, where .. " needs a count")
		elseif quest.Kind == "Deliver" then
			check(Catalog.Fish[quest.FishId] ~= nil, where .. " wants unknown fish " .. tostring(quest.FishId))
			check(biting[quest.FishId], where .. " wants " .. tostring(quest.FishId) .. ", which never bites")
		elseif quest.Kind == "DeliverRarity" then
			check(Catalog.Rarities[quest.Rarity] ~= nil, where .. " names unknown rarity " .. tostring(quest.Rarity))
		else
			check(quest.Kind == "DeliverMutated", where .. " has unknown kind " .. tostring(quest.Kind))
		end
		check(#Cove.goal(quest, 0, "Fish") > 0, where .. " has no goal text")
	end
end
local function rarityOf(id)
	return Catalog.Fish[id] and Catalog.Fish[id].Rarity
end
local tuna = { FishId = "YellowfinTuna", Mutation = "Normal" }
check(Cove.accepts(Cove.Quests.Hale[2], tuna, rarityOf), "The captain accepts a tuna")
check(
	not Cove.accepts(Cove.Quests.Hale[2], { FishId = "Sardine", Mutation = "Normal" }, rarityOf),
	"...but not a sardine"
)
check(Cove.accepts({ Kind = "DeliverRarity", Rarity = "Rare" }, tuna, rarityOf), "A Rare tuna counts as Rare or rarer")
check(
	Cove.accepts({ Kind = "DeliverRarity", Rarity = "Uncommon" }, tuna, rarityOf),
	"A Rare tuna counts as Uncommon or rarer"
)
check(not Cove.accepts({ Kind = "DeliverRarity", Rarity = "Epic" }, tuna, rarityOf), "A Rare tuna isn't Epic")
check(not Cove.accepts({ Kind = "DeliverMutated" }, tuna, rarityOf), "A normal fish isn't mutated")
check(
	Cove.accepts({ Kind = "DeliverMutated" }, { FishId = "Sardine", Mutation = "Neon" }, rarityOf),
	"A neon fish is mutated"
)
check(Cove.goal(Cove.Quests.Hale[1], 4) == "Catch 10 fish (4 / 10)", "Catch goals count progress")
check(Cove.goal(Cove.Quests.Hale[1], 40) == "Catch 10 fish (10 / 10)", "Catch progress caps at the target")

-- Rod stock: real skins, priced, no duplicates, and the wear is valid.
local stocked = {}
for _, rod in Cove.Rods do
	check(RodSkins.valid(rod.SkinId), "Flint sells unknown rod " .. tostring(rod.SkinId))
	check(not stocked[rod.SkinId], "Flint lists " .. rod.SkinId .. " twice")
	stocked[rod.SkinId] = true
	check(type(rod.Price) == "number" and rod.Price > 0 and rod.Price % 1 == 0, rod.SkinId .. " needs a price")
end
check(#Cove.Rods <= 5, "The rod list fits the dialogue (five rods and Bye)")
check(RodSkins.validWear(Cove.ROD_WEAR), "Shop rods have a valid wear")

local profile = BoatData.decode(nil)
profile.Cash = 1000
check(BoatData.buyRodSkin(profile, "BambooRod", 500, Cove.ROD_WEAR) == "Purchased", "A preview passes with the cash")
check(profile.Cash == 1000 and next(profile.RodSkinCopies) == nil, "A preview changes nothing")
check(BoatData.buyRodSkin(profile, "BambooRod", 500, Cove.ROD_WEAR, 7) == "Purchased", "Buying a rod works")
check(profile.Cash == 500 and profile.RodSkins.BambooRod == 1, "Buying charges and adds the skin")
check(
	profile.RodSkinCopies[1].Serial == 7 and profile.RodSkinCopies[1].Wear == Cove.ROD_WEAR,
	"The copy keeps its serial and wear"
)
check(profile.Angler.Stats.CoinsSpent == 500, "Spending is recorded")
check(
	BoatData.buyRodSkin(profile, "MusketRod", 2000, Cove.ROD_WEAR, 1) == "InsufficientFunds",
	"Can't buy without the cash"
)
check(BoatData.buyRodSkin(profile, "NotARod", 1, Cove.ROD_WEAR, 1) == "UnknownRod", "Unknown rods are refused")
check(not pcall(BoatData.buyRodSkin, profile, "BambooRod", 1, Cove.ROD_WEAR, 7), "A serial can't be owned twice")
check(BoatData.decode(profile).RodSkins.BambooRod == 1, "Bought rods survive a save")

-- The galley: 15 a day, from the hand then the backpack, never locked fish, fresh each day.
local function fish(id, value, mutation)
	return {
		FishId = id,
		Mutation = mutation or "Normal",
		Kg = 2,
		Value = value,
		CaughtAt = 100,
		Rarity = 10,
		Relative = 1,
	}
end
local angler = Data.decode(nil)
angler.Hand = fish("Sardine", 12.7)
for i = 1, 20 do
	table.insert(
		angler.Backpack,
		{ Fish = fish("Mackerel", 10), X = i, Y = 1, R = 0, Locked = if i == 1 then true else nil }
	)
end
check(Cove.salesLeft(nil, 5) == 15 and Cove.salesLeft({ Day = 4, Count = 15 }, 5) == 15, "A new day starts fresh")
check(Cove.salesLeft({ Day = 5, Count = 9 }, 5) == 6, "Sales today count down")

local onlyHand, sold, earned = Data.sellToCove(angler, 5, Cove.DAILY_SALES, true)
check(
	sold == 1 and earned == 12 and onlyHand.Hand == nil and #onlyHand.Backpack == 20,
	"Selling the held fish sells just that"
)
local all
all, sold, earned = Data.sellToCove(angler, 5, Cove.DAILY_SALES, false)
check(sold == 15 and earned == 12 + 14 * 10, "Selling everything stops at the daily limit")
check(all.CoveSales.Day == 5 and all.CoveSales.Count == 15, "The day's sales are saved")
check(#all.Backpack == 6 and all.Backpack[1].Locked, "Locked and leftover fish stay in the backpack")
check(all.Stats.FishSold == 15 and all.Stats.CoinsEarned == earned, "Sales count toward the stats")
local again
again, sold = Data.sellToCove(all, 5, Cove.DAILY_SALES, false)
check(sold == 0 and #again.Backpack == 6, "Bess declines once the cove has enough")
again, sold = Data.sellToCove(all, 6, Cove.DAILY_SALES, false)
check(sold == 5 and again.CoveSales.Count == 5 and #again.Backpack == 1, "The next day she buys again")
check(Data.decode(Data.decode(all)).CoveSales.Count == 15, "Sales decode stably")
check(not pcall(Data.decode, { CoveSales = { Day = 1, Count = -1 } }), "Negative sales are rejected")
check(not pcall(Data.decode, { CoveSales = { Day = "1", Count = 1 } }), "Text days are rejected")
check(Cove.day(0) == 0 and Cove.day(Cove.DAY_SECONDS * 3 + 5) == 3, "Days follow the in-game clock")

-- Deliveries take the first match from the hand, then the backpack, never a locked fish.
local carrier = Data.decode(nil)
carrier.Hand = fish("Sardine", 5)
table.insert(carrier.Backpack, { Fish = fish("YellowfinTuna", 90), X = 1, Y = 1, R = 0, Locked = true })
table.insert(carrier.Backpack, { Fish = fish("YellowfinTuna", 80), X = 3, Y = 1, R = 0 })
local function wantsTuna(record)
	return Cove.accepts(Cove.Quests.Hale[2], record, rarityOf)
end
local after, given = Data.deliverFish(carrier, wantsTuna)
check(
	given and given.Value == 80 and #after.Backpack == 1 and after.Backpack[1].Locked,
	"The unlocked tuna is handed over"
)
check(after.Hand ~= nil, "The held sardine stays in hand")
check(Data.deliverFish(after, wantsTuna) == nil, "A locked tuna is never taken")
local handed
handed, given = Data.deliverFish(carrier, function(record)
	return record.FishId == "Sardine"
end)
check(given and handed.Hand == nil, "A matching held fish goes first")

-- Saved quest progress.
local quests = Data.decode({ CoveQuests = { Hale = { Step = 2, Accepted = true, Base = 40 } } })
check(quests.CoveQuests.Hale.Step == 2 and quests.CoveQuests.Hale.Base == 40, "Quest progress survives a reload")
check(Data.decode(nil).CoveQuests ~= nil, "New anglers start with no cove quests")
check(not pcall(Data.decode, { CoveQuests = { Hale = { Step = 0 } } }), "Step 0 is rejected")
check(not pcall(Data.decode, { CoveQuests = { Hale = { Step = 1, Accepted = "yes" } } }), "Odd acceptance is rejected")
check(Cove.quest("Hale", #Cove.Quests.Hale + 1) == nil, "Past the last quest there is nothing")

print(string.format("Pirate Cove checks passed (%d)", checks))
