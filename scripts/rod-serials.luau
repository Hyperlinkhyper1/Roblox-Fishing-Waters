-- Shared-store simulations execute the production allocator and migration.
local Serials = require("../src/server/RodSerials")
local Data = require("../src/server/BoatData")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local store = { records = {}, retries = true }
function store:UpdateAsync(key, transform)
	local result = transform(self.records[key])
	if self.interleave then
		local callback = self.interleave
		self.interleave = nil
		callback()
	end
	if self.retries then
		result = transform(self.records[key])
	end
	if self.failBefore == key then
		error("Save failed")
	end
	self.records[key] = result
	if self.failAfter == key then
		error("Response lost after commit")
	end
	return result
end
local function serverA(id, count)
	return Serials.reserve(store, id, count)
end
local function serverB(id, count)
	return Serials.reserve(store, id, count)
end
check(serverA("BoneRod") == 1 and serverB("BoneRod") == 2, "Different servers share one sequence")
check(serverB("TideboundRod") == 1, "Each skin has one global edition sequence")
local interleaved
store.interleave = function()
	interleaved = serverB("BoneRod")
end
check(serverA("BoneRod") == 4 and interleaved == 3, "Concurrent optimistic retries never return the same serial")
check(Serials.reserve(store, "BoneRod") == 5, "A fresh allocator uses the persisted sequence")
store.failAfter = "RodSerial_v1_BoneRod"
check(not pcall(serverA, "BoneRod"), "Ambiguous reservation failures do not award a serial")
store.failAfter = nil
check(serverB("BoneRod") == 7, "A committed reservation with a lost response is never recycled")
store.records.RodSerial_v1_BadRod = "corrupt"
check(not pcall(serverA, "BadRod"), "Corrupt global counters fail closed")

local function legacy()
	return Data.decode({
		Version = 1,
		Cash = 700,
		OwnedBoats = {},
		RodSkinCopies = {
			{ SkinId = "BoneRod", Serial = 1 },
			{ SkinId = "BoneRod", Serial = 2 },
			{ SkinId = "TideboundRod", Serial = 1 },
		},
		NextRodSkinSerial = { BoneRod = 3, TideboundRod = 2 },
		EquippedRodSkin = "BoneRod",
		EquippedRodSkinSerial = 2,
		GroupRodClaimed = true,
	})
end
store.records.Player_A, store.records.Player_B = legacy(), legacy()
local a = Serials.migrate(store, "Player_A", legacy())
local b = Serials.migrate(store, "Player_B", legacy())
local seen = {}
for _, profile in { a, b } do
	for _, copy in profile.RodSkinCopies do
		local key = copy.SkinId .. ":" .. copy.Serial
		check(not seen[key], "Legacy players receive globally distinct numbers")
		seen[key] = true
	end
	check(
		profile.EquippedRodSkinSerial == profile.RodSkinCopies[2].Serial,
		"Migration preserves the selected duplicate"
	)
	check(
		profile.GroupRodClaimed and profile.Cash == 700 and #profile.RodSkinCopies == 3,
		"Migration preserves claims, cash and copies"
	)
end
local counter = store.records.RodSerial_v1_BoneRod
local again = Serials.migrate(store, "Player_A", Data.decode(a))
check(
	again.RodSkinCopies[1].Serial == a.RodSkinCopies[1].Serial and store.records.RodSerial_v1_BoneRod == counter,
	"Reloading global copies never reserves or renumbers again"
)
-- A stale concurrent loader must keep the migration already committed by A.
local stale = Serials.migrate(store, "Player_A", legacy())
check(
	stale.EquippedRodSkinSerial == a.EquippedRodSkinSerial,
	"Concurrent migrations retain the first committed assignment"
)

store.records.Player_Fail = legacy()
store.failBefore = "Player_Fail"
check(not pcall(Serials.migrate, store, "Player_Fail", legacy()), "Failed migration saves do not expose an inventory")
check(store.records.Player_Fail.RodSerialScope == nil, "A failed migration leaves the old save intact")
store.failBefore = nil
local recovered = Serials.migrate(store, "Player_Fail", legacy())
check(
	recovered.RodSkinCopies[1].Serial > stale.RodSkinCopies[1].Serial,
	"Migration retries skip abandoned reservations"
)

local newProfile = Data.decode(nil)
newProfile.Cash = 350
local serial = serverA("BoneRod")
check(
	Data.openRodCrate(newProfile, "TideCrate", "BoneRod", serial) == "Opened",
	"Crates accept a reserved global number"
)
check(newProfile.RodSkinCopies[1].Serial == serial, "Global number is saved without being reset to a local counter")
newProfile.Cash = 350
check(
	not pcall(Data.openRodCrate, newProfile, "TideCrate", "BoneRod"),
	"Missing reservations cannot create locally numbered copies"
)
check(
	not pcall(Data.openRodCrate, newProfile, "TideCrate", "BoneRod", serial),
	"A reserved number cannot be inserted twice"
)
print(`Global rod serials: {checks} shared-server, contention, failure and migration checks passed`)
