-- The business and wallet belong to the save. Each angler keeps their own
-- carried fish and bag, so two crew members can fish and unload concurrently.
-- The creator's original hand/bag stay at their legacy locations in Angler.
local BoatData = if script then require(script.Parent.BoatData) else require("./BoatData")
local Profile = {}

function Profile.view(raw, userId)
	local result = BoatData.decode(raw)
	local info = result.SaveInfo
	if not info or info.OwnerUserId == userId then return result end
	assert(result.CompanyCrew == nil or type(result.CompanyCrew) == "table", "Invalid company crew inventory")
	local personal = (result.CompanyCrew or {})[tostring(userId)] or {}
	assert(type(personal) == "table", "Invalid angler inventory")
	result.Angler.Hand = personal.Hand
	result.Angler.Backpack = personal.Backpack or {}
	return BoatData.decode(result)
end

function Profile.merge(canonical, changed, userId)
	local result = BoatData.decode(changed)
	assert(canonical.CompanyCrew == nil or type(canonical.CompanyCrew) == "table", "Invalid company crew inventory")
	result.CompanyCrew = table.clone(canonical.CompanyCrew or {})
	if result.SaveInfo and result.SaveInfo.OwnerUserId ~= userId then
		result.CompanyCrew[tostring(userId)] = {
			Hand = result.Angler.Hand,
			Backpack = result.Angler.Backpack,
		}
		result.Angler.Hand = canonical.Angler.Hand
		result.Angler.Backpack = canonical.Angler.Backpack
	end
	return BoatData.decode(result)
end

return Profile
