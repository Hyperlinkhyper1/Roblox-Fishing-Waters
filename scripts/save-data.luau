-- Pure rules used by save selection and every shared-wallet transaction.
-- Run: lute run scripts/save-data.luau
local Data = require("../src/server/SaveData")
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function rejects(callback, message)
	check(not pcall(callback), message)
end

check(Data.MAX_SLOTS == 3 and Data.MAX_MEMBERS == 5, "Three owner slots, five company members")
for slot = 1, 3 do check(Data.validSlot(slot), "All three owner slots are accepted") end
for _, slot in { 0, 4, -1, 1.1, "1", math.huge, 0 / 0, {} } do
	check(not Data.validSlot(slot), "Invalid slots cannot create extra saves")
end
check(Data.key(123, 1) == "Player_123", "Existing profile stays in slot one without copying")
check(Data.key(123, 2) == "Player_123_Slot_2", "Slot two has its own key")
check(Data.key(123, 3) == "Player_123_Slot_3", "Slot three has its own key")
check(Data.id(123, 2) == "123_2", "Stable company identity does not depend on company name")
check(Data.key(-1, 2) == "Player_-1_Slot_2", "Studio multiplayer identities work")
for _, owner in { 0, "123", math.huge, 0 / 0, 2 ^ 53, 2.5 } do
	check(not Data.validOwner(owner), "Invalid owners are rejected")
end
rejects(function() Data.key(123, 4) end, "Storage keys cannot bypass the slot limit")

local raw = { Cash = 475, OwnedBoats = { Rowboat = true } }
local legacy = Data.info(raw, 123, 1)
check(legacy.OwnerUserId == 123 and legacy.Slot == 1 and not legacy.Multiplayer, "Legacy saves are private")
check(legacy.Members["123"] and Data.memberCount(legacy) == 1, "Creator always occupies one member space")
check(raw.Cash == 475 and raw.SaveInfo == nil, "Migration never alters progress or its input")
check(Data.canPlay(legacy, 123) and not Data.canPlay(legacy, 456), "Legacy save access belongs to creator")
check(Data.cleanName("   Gullhaven   Fisheries  ") == "Gullhaven Fisheries", "Names trim and normalize spaces")
check(Data.cleanName(string.rep("é", 32)) == string.rep("é", 32), "Name limit counts UTF-8 characters")
for _, name in { "", "   ", string.rep("x", 33), "Bad\nname", "Bad\tname", string.char(255), false } do
	rejects(function() Data.cleanName(name) end, "Invalid company names are rejected")
end

local fresh = Data.createInfo(123, 2, "Tide & Tackle", true, 100, "company-server")
check(fresh.CreatedAt == 100 and fresh.UpdatedAt == 100 and fresh.Revision == 0, "Creation initializes timestamps")
check(fresh.ServerId == "company-server", "Offline company server identity persists")
local profile = { Cash = 900, SaveInfo = fresh }
local clone = Data.info(profile, 123, 2)
clone.Members["456"] = true
clone.MemberNames["456"] = "Friend"
check(fresh.Members["456"] == nil and fresh.MemberNames["456"] == nil, "Every retry gets independent membership tables")
clone.Name = "Changed"
check(fresh.Name == "Tide & Tackle", "Save settings are isolated from source record")
rejects(function() Data.info(profile, 456, 2) end, "An unrelated account cannot claim a company")
rejects(function() Data.info(profile, 123, 3) end, "A company cannot occupy the wrong slot")

local info = Data.info(profile, 123, 2)
rejects(function() Data.join(info, 456, false, "Stranger") end, "Knowing a save ID grants no access")
check(info.Members["456"] == nil, "Failed join leaves no membership")
Data.join(info, 456, true, "Friend One")
check(Data.canPlay(info, 456) and info.MemberNames["456"] == "Friend One", "Creator's friend can join")
Data.join(info, 456, false, "Friend One")
check(Data.memberCount(info) == 2, "Rejoining is idempotent and takes no extra slot")
for _, userId in { 457, 458, 459 } do Data.join(info, userId, true) end
check(Data.memberCount(info) == 5, "Creator and four friends fill the company")
rejects(function() Data.join(info, 460, true) end, "Sixth player is refused")
check(info.Members["460"] == nil, "Rejected sixth player does not corrupt membership")
Data.join(info, 123, false)
check(Data.memberCount(info) == 5, "Owner may rejoin a full company")

rejects(function() Data.edit(info, 456, "Stolen", false) end, "Members cannot rename or privatize a save")
rejects(function() Data.edit(info, 123, "Broken", false, 123) end, "Creator cannot remove themselves")
check(info.Name == "Tide & Tackle" and info.Multiplayer, "Rejected setting edit has no partial effects")
Data.edit(info, 123, "Coastal Company", false)
check(info.Name == "Coastal Company" and not info.Multiplayer, "Owner can edit name and multiplayer")
check(Data.canPlay(info, 123) and not Data.canPlay(info, 456), "Turning off multiplayer blocks guest play")
check(Data.memberCount(info) == 5, "Private mode retains roster for later reactivation")
rejects(function() Data.join(info, 456, true) end, "Existing member cannot enter private save")
Data.edit(info, 123, nil, true, 459)
check(info.Multiplayer and info.Members["459"] == nil and Data.memberCount(info) == 4, "Owner can remove a member")
Data.join(info, 460, true, "New Friend")
check(Data.memberCount(info) == 5, "Removing a member frees capacity")
Data.leave(info, 460)
check(info.Members["460"] == nil and info.MemberNames["460"] == nil, "Leaving frees membership and display name")
rejects(function() Data.leave(info, 123) end, "Company ownership remains with its original creator")
Data.touch(info, 200)
Data.touch(info, 201)
check(info.Revision == 2 and info.UpdatedAt == 201 and info.CreatedAt == 100, "Revisions track committed updates")

-- Two incoming joins can both initially see one place. UpdateAsync retries the
-- losing transform against the winner's committed record before allowing it.
local latest = { Cash = 400, SaveInfo = info }
local firstRead = Data.info(latest, 123, 2)
local secondRead = Data.info(latest, 123, 2)
Data.join(firstRead, 500, true)
Data.join(secondRead, 501, true)
check(Data.memberCount(firstRead) == 5 and Data.memberCount(secondRead) == 5, "Both optimistic first reads appear valid")
latest.SaveInfo = firstRead
rejects(function() Data.join(Data.info(latest, 123, 2), 501, true) end, "Retry enforces cap against latest committed membership")
check(Data.memberCount(latest.SaveInfo) == 5 and latest.SaveInfo.Members["501"] == nil, "Racing joins never admit a sixth member")
check(latest.Cash == 400, "Membership edits leave shared company money untouched")

local malformed = Data.info(latest, 123, 2)
malformed.Members["999"] = true
rejects(function() Data.info({ SaveInfo = malformed }, 123, 2) end, "Oversized stored roster fails closed")
malformed = Data.info(latest, 123, 2)
malformed.Members["0123"] = true
rejects(function() Data.info({ SaveInfo = malformed }, 123, 2) end, "Noncanonical identity strings cannot hide duplicate members")
malformed = Data.info(latest, 123, 2)
malformed.Members["123"] = nil
rejects(function() Data.info({ SaveInfo = malformed }, 123, 2) end, "Malformed saves cannot remove creator")
malformed = Data.info(latest, 123, 2)
malformed.Revision = math.huge
rejects(function() Data.info({ SaveInfo = malformed }, 123, 2) end, "Nonfinite revisions fail closed")

local expanded = Data.createInfo(700, 1, "Room for a crew", true, 100)
check(expanded.PlotExpanded == true, "Multiplayer saves receive the expanded plot entitlement")
Data.edit(expanded, 700, nil, false)
check(not expanded.Multiplayer and expanded.PlotExpanded, "Disabling friends keeps land used by existing construction")
check(Data.info({ SaveInfo = expanded }, 700, 1).PlotExpanded, "Expanded land survives a saved solo round trip")
local olderCompany = Data.createInfo(701, 2, "Older company", true, 100)
olderCompany.PlotExpanded = nil
check(Data.info({ SaveInfo = olderCompany }, 701, 2).PlotExpanded, "Existing multiplayer saves automatically receive larger plots")
local soloPlot = Data.createInfo(702, 1, "Small plot", false, 100)
check(not soloPlot.PlotExpanded, "Ordinary solo plots keep their original size")
Data.edit(soloPlot, 702, nil, true)
check(soloPlot.PlotExpanded, "Enabling multiplayer upgrades an existing plot without resetting it")
expanded.PlotExpanded = "large"
rejects(function() Data.info({ SaveInfo = expanded }, 700, 1) end, "Invalid plot size markers cannot alter saved property")

print("Save ownership/company rules: " .. checks .. " checks passed.")
