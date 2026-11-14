-- Save ownership and company membership rules. All transforms are non-yielding
-- and run against the latest record inside the wallet's UpdateAsync callback.
local SaveData = {}

SaveData.MAX_SLOTS = 3
SaveData.MAX_MEMBERS = 5

local function integer(value)
	return type(value) == "number" and value == value and math.abs(value) < 2 ^ 53 and value % 1 == 0
end

function SaveData.validOwner(owner): boolean
	-- Studio's local multiplayer clients use negative user IDs.
	return integer(owner) and owner ~= 0
end

function SaveData.validSlot(slot): boolean
	return integer(slot) and slot >= 1 and slot <= SaveData.MAX_SLOTS
end

local function identity(owner, slot)
	assert(SaveData.validOwner(owner), "Invalid save owner.")
	assert(SaveData.validSlot(slot), "Choose a save slot from 1 to 3.")
end

function SaveData.key(owner, slot): string
	identity(owner, slot)
	-- The first slot keeps its original key; upgrading never copies or resets it.
	return "Player_" .. tostring(owner) .. (if slot == 1 then "" else "_Slot_" .. tostring(slot))
end

function SaveData.id(owner, slot): string
	identity(owner, slot)
	return tostring(owner) .. "_" .. tostring(slot)
end

function SaveData.cleanName(name): string
	assert(type(name) == "string" and #name <= 256, "Enter a company name of 1 to 32 characters.")
	assert(not string.find(name, "%c"), "Company names cannot contain control characters.")
	local cleaned = string.gsub(string.gsub(name, "^%s*(.-)%s*$", "%1"), " +", " ")
	local length = utf8.len(cleaned)
	assert(length and length >= 1 and length <= 32, "Enter a company name of 1 to 32 characters.")
	return cleaned
end

-- The type of company a new save starts as (Shared.Branches). The other branch
-- can be bought later; existing saves without a type are fishing companies.
SaveData.COMPANY_TYPES = { Fishing = true, Cafe = true }

function SaveData.cleanCompanyType(kind): string
	if kind == nil then return "Fishing" end
	assert(type(kind) == "string" and SaveData.COMPANY_TYPES[kind], "Choose a fishing company or a café.")
	return kind
end

-- Company icons are Roblox decal or image asset IDs. Players may paste the bare
-- number, an rbxassetid:// string or a Creator Store / library URL. An empty
-- value clears the icon. Returns false for "clear", or the asset ID.
function SaveData.cleanIcon(value): number | false
	if value == nil or value == false or value == "" then return false end
	if type(value) == "number" then
		assert(integer(value) and value > 0, "Enter a decal or image ID (numbers only).")
		return value
	end
	assert(type(value) == "string" and #value <= 300, "Enter a decal or image ID (numbers only).")
	local trimmed = string.match(value, "^%s*(.-)%s*$")
	if trimmed == "" then return false end
	local digits = string.match(trimmed, "^(%d+)$")
		or string.match(trimmed, "rbxassetid://(%d+)")
		or string.match(trimmed, "[?&]id=(%d+)")
		or string.match(trimmed, "/(%d+)/?[^/]*$")
		or string.match(trimmed, "/(%d+)/")
	assert(digits and #digits <= 16, "Enter a decal or image ID (numbers only).")
	local id = tonumber(digits)
	assert(integer(id) and id > 0, "Enter a decal or image ID (numbers only).")
	return id
end

local function timestamp(value)
	return integer(value) and value >= 0
end

local function memberKey(key)
	if type(key) ~= "string" then return false end
	local userId = tonumber(key)
	return SaveData.validOwner(userId) and tostring(userId) == key
end

local function memberName(name)
	return type(name) == "string" and #name <= 128 and not string.find(name, "%c") and utf8.len(name) ~= nil
end

function SaveData.createInfo(owner, slot, name, multiplayer, now, serverId)
	identity(owner, slot)
	assert(type(multiplayer) == "boolean", "Choose whether this save allows multiplayer.")
	assert(timestamp(now), "Invalid save timestamp.")
	assert(serverId == nil or (type(serverId) == "string" and #serverId > 0 and #serverId <= 128
		and not string.find(serverId, "%c")), "Invalid company server.")
	return {
		OwnerUserId = owner,
		Slot = slot,
		Name = SaveData.cleanName(name),
		Multiplayer = multiplayer,
		PlotExpanded = multiplayer,
		Members = { [tostring(owner)] = true },
		MemberNames = {},
		Revision = 0,
		CreatedAt = now,
		UpdatedAt = now,
		ServerId = serverId,
	}
end

function SaveData.memberCount(info): number
	local count = 0
	for _, member in info.Members do
		if member then count += 1 end
	end
	return count
end

function SaveData.info(raw, owner, slot)
	identity(owner, slot)
	assert(raw == nil or type(raw) == "table", "Invalid saved profile.")
	local source = raw and raw.SaveInfo
	if source == nil then
		return SaveData.createInfo(owner, slot, "My fishing company", false, 0)
	end
	assert(type(source) == "table" and source.OwnerUserId == owner and source.Slot == slot,
		"Save ownership does not match this slot.")
	assert(type(source.Multiplayer) == "boolean", "Invalid saved multiplayer setting.")
	assert(source.PlotExpanded == nil or type(source.PlotExpanded) == "boolean", "Invalid saved plot size.")
	assert(type(source.Members) == "table", "Invalid company membership.")
	assert(source.Members[tostring(owner)] == true, "The creator must belong to their company.")
	assert(source.MemberNames == nil or type(source.MemberNames) == "table", "Invalid company member names.")
	assert(integer(source.Revision) and source.Revision >= 0, "Invalid save revision.")
	assert(source.CreatedAt == nil or timestamp(source.CreatedAt), "Invalid save creation time.")
	assert(source.UpdatedAt == nil or timestamp(source.UpdatedAt), "Invalid save update time.")
	assert(source.Icon == nil or (integer(source.Icon) and source.Icon > 0), "Invalid company icon.")
	local result = SaveData.createInfo(owner, slot, source.Name, source.Multiplayer, source.CreatedAt or 0, source.ServerId)
	-- Turning multiplayer off keeps land already used by saved construction.
	result.PlotExpanded = source.PlotExpanded == true or source.Multiplayer == true
	result.UpdatedAt, result.Revision = source.UpdatedAt or result.CreatedAt, source.Revision
	result.Icon = source.Icon
	result.Members, result.MemberNames = {}, {}
	for key, value in source.Members do
		assert(memberKey(key) and value == true, "Invalid company member.")
		result.Members[key] = true
	end
	assert(SaveData.memberCount(result) <= SaveData.MAX_MEMBERS, "A company can have at most five players.")
	for key, name in source.MemberNames or {} do
		assert(result.Members[key] and memberName(name), "Invalid company member name.")
		result.MemberNames[key] = name
	end
	return result
end

function SaveData.canPlay(info, userId): boolean
	return SaveData.validOwner(userId) and (userId == info.OwnerUserId
		or (info.Multiplayer == true and info.Members[tostring(userId)] == true))
end

-- info() returns an independent clone. The following operations mutate that
-- clone and return it, leaving the source DataStore record untouched on failure.
function SaveData.join(info, userId, isFriend, name)
	assert(SaveData.validOwner(userId), "Invalid company member.")
	local key = tostring(userId)
	if userId ~= info.OwnerUserId then
		assert(info.Multiplayer, "This save has multiplayer turned off.")
		if not info.Members[key] then
			assert(isFriend == true, "Only the creator's Roblox friends can join this company.")
			assert(SaveData.memberCount(info) < SaveData.MAX_MEMBERS, "This company already has five players.")
		end
	end
	assert(name == nil or memberName(name), "Invalid company member name.")
	info.Members[key] = true
	if name then info.MemberNames[key] = name end
	return info
end

-- icon: nil keeps the current icon, false clears it, a number replaces it.
function SaveData.edit(info, actorId, name, multiplayer, removeUserId, icon)
	assert(actorId == info.OwnerUserId, "Only the company creator can edit this save.")
	local nextName = if name == nil then info.Name else SaveData.cleanName(name)
	assert(multiplayer == nil or type(multiplayer) == "boolean", "Invalid multiplayer setting.")
	if removeUserId ~= nil then
		assert(SaveData.validOwner(removeUserId), "Invalid company member.")
		assert(removeUserId ~= info.OwnerUserId, "The company creator cannot be removed.")
	end
	info.Name = nextName
	if multiplayer ~= nil then info.Multiplayer = multiplayer end
	info.PlotExpanded = info.PlotExpanded == true or info.Multiplayer == true
	if icon == false then
		info.Icon = nil
	elseif icon ~= nil then
		assert(integer(icon) and icon > 0, "Invalid company icon.")
		info.Icon = icon
	end
	if removeUserId ~= nil then
		local key = tostring(removeUserId)
		info.Members[key], info.MemberNames[key] = nil, nil
	end
	return info
end

function SaveData.leave(info, userId)
	assert(SaveData.validOwner(userId), "Invalid company member.")
	assert(userId ~= info.OwnerUserId, "The creator cannot leave their own company.")
	local key = tostring(userId)
	info.Members[key], info.MemberNames[key] = nil, nil
	return info
end

function SaveData.touch(info, now)
	assert(timestamp(now), "Invalid save timestamp.")
	assert(integer(info.Revision) and info.Revision >= 0 and info.Revision < 2 ^ 53 - 1, "Invalid save revision.")
	info.Revision += 1
	info.UpdatedAt = now
	return info
end

return SaveData
