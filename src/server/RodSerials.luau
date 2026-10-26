-- One durable counter per skin, shared by every server in the experience.
-- Reserve before saving a player's profile; failed saves may leave gaps, but a
-- reserved number is never reused. No yielding calls run inside profile transforms.
local BoatData = if script then require(script.Parent.BoatData) else require("./BoatData")
local RodSerials = {}
RodSerials.Scope = "GlobalV1"

function RodSerials.reserve(store, skinId: string, count: number?): number
	local amount = count or 1
	assert(type(skinId) == "string" and #skinId > 0, "Missing serial skin")
	assert(amount >= 1 and amount % 1 == 0, "Invalid serial reservation")
	local last = store:UpdateAsync("RodSerial_v1_" .. skinId, function(raw)
		local previous = if raw == nil then 0 else raw
		assert(type(previous) == "number" and previous >= 0 and previous % 1 == 0, "Invalid global serial counter")
		assert(previous + amount < 2 ^ 53 - 1, "Global skin serial limit reached")
		return previous + amount
	end)
	assert(type(last) == "number" and last >= amount and last % 1 == 0, "Serial reservation was not saved")
	return last - amount + 1
end

-- Legacy per-player numbers can collide. Renumber all copies before exposing
-- the inventory, keeping the selected copy and claim receipts intact. Concurrent
-- loads may reserve unused ranges; only the first committed migration is kept.
function RodSerials.migrate(store, key: string, loaded)
	if loaded.RodSerialScope == RodSerials.Scope then
		return loaded
	end
	local ranges = {}
	for id, count in loaded.RodSkins do
		ranges[id] = { first = RodSerials.reserve(store, id, count), count = count }
	end
	local saved = store:UpdateAsync(key, function(raw)
		local profile = BoatData.decode(raw)
		if profile.RodSerialScope == RodSerials.Scope then
			return profile
		end
		local used = {}
		local equippedId, equippedSerial = profile.EquippedRodSkin, profile.EquippedRodSkinSerial
		for _, copy in profile.RodSkinCopies do
			local id, oldSerial = copy.SkinId, copy.Serial
			local range = ranges[id]
			local index = (used[id] or 0) + 1
			assert(range and index <= range.count, "Inventory changed during serial migration; retry loading")
			copy.Serial = range.first + index - 1
			if equippedId == id and equippedSerial == oldSerial then
				profile.EquippedRodSkinSerial = copy.Serial
			end
			used[id] = index
		end
		profile.RodSerialScope = RodSerials.Scope
		return BoatData.decode(profile)
	end)
	assert(saved ~= nil, "Serial migration was not saved")
	return BoatData.decode(saved)
end

return RodSerials
