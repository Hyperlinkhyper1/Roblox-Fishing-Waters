-- Save directories contain discovery pointers only. The creator's wallet record
-- owns the roster, settings and progress, including the single company wallet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local SaveData = require(script.Parent.SaveData)
local BoatData = require(script.Parent.BoatData)
local RodSerials = require(script.Parent.RodSerials)
local Worth = require(script.Parent.CompanyWorth)

local Service = {}
local store, callbacks, sessionOnly
local opened, started = false, false
local caches, busy, lastRequest, pendingTeleports, admitted = {}, {}, {}, {}, {}
local discoveryCache = {}
local nextDiscoveryRead = 0

-- Friend discovery shares one paced read lane and cache across the server.
-- Fifteen selectors must not each start their own five-reads/second scan.
local function discoveryRead(key, lifetime)
	local cached = discoveryCache[key]
	if cached then
		while cached.loading do task.wait(0.1) end
		if cached.expires > os.clock() then return cached.value end
	end
	cached = { loading = true, expires = 0 }
	discoveryCache[key] = cached
	local at = math.max(os.clock(), nextDiscoveryRead)
	nextDiscoveryRead = at + 1
	if at > os.clock() then task.wait(at - os.clock()) end
	local ok, value = pcall(store.GetAsync, store, key)
	cached.loading = false
	if not ok then error(value) end
	cached.value, cached.expires = value, os.clock() + lifetime
	return value
end

local function directoryKey(owner)
	return "SaveDirectory_v1_" .. owner
end

local function directory(raw)
	if raw == nil then return { Version = 1, Slots = {}, Joined = {} } end
	assert(type(raw) == "table" and raw.Version == 1 and type(raw.Slots) == "table", "Save directory is unavailable.")
	return { Version = 1, Slots = table.clone(raw.Slots), Joined = table.clone(raw.Joined or {}) }
end

local function summary(profile, owner, slot, withMembers)
	local info = SaveData.info(profile, owner, slot)
	local members = {}
	if withMembers then
		for id in info.Members do
			table.insert(members, { UserId = tonumber(id), Name = info.MemberNames[id] or ("Angler " .. id) })
		end
		table.sort(members, function(a, b) return a.UserId < b.UserId end)
	end
	return {
		Exists = true, OwnerUserId = owner, Slot = slot, Name = info.Name,
		OwnerName = info.MemberNames[tostring(owner)],
		Multiplayer = info.Multiplayer, MemberCount = SaveData.memberCount(info), Members = members,
		NetWorth = Worth.calculate(profile), Icon = info.Icon,
		-- nil for saves from before branches: a fishing company.
		Branches = if type(profile) == "table" and type(profile.Branches) == "table" then table.clone(profile.Branches) else nil,
	}
end

-- Runs one job per slot at the same time and waits for all of them. Each job
-- yields on its own DataStore request, so three slots cost one round trip
-- instead of three. coroutine.wrap starts every job immediately; a job that
-- finishes without yielding (mocks, cached reads) never needs the wait loop.
local function eachSlot(job)
	local results, failures, remaining = {}, {}, SaveData.MAX_SLOTS
	for slot = 1, SaveData.MAX_SLOTS do
		coroutine.wrap(function()
			local ok, value = pcall(job, slot)
			if ok then results[slot] = value else failures[slot] = value end
			remaining -= 1
		end)()
	end
	while remaining > 0 do task.wait() end
	for slot = 1, SaveData.MAX_SLOTS do
		if failures[slot] ~= nil then error(failures[slot], 0) end
	end
	return results
end

-- A failed index write never rolls back or replaces the authoritative save.
local function indexSave(profile, owner, slot)
	local entry = summary(profile, owner, slot, false)
	store:UpdateAsync(directoryKey(owner), function(raw)
		local index = directory(raw)
		index.Slots[tostring(slot)] = entry
		return index
	end)
	discoveryCache[directoryKey(owner)] = nil
end

-- Accepts decal and image assets. If Roblox cannot answer, the ID is kept;
-- rbxthumb renders nothing for an ID that is not an image.
local function checkIcon(icon)
	if not icon or sessionOnly then return icon end
	local ok, product = pcall(MarketplaceService.GetProductInfo, MarketplaceService, icon, Enum.InfoType.Asset)
	if ok and type(product) == "table" and product.AssetTypeId ~= nil then
		assert(product.AssetTypeId == 1 or product.AssetTypeId == 13, "That ID is not a decal or image.")
	end
	return icon
end

local function filterName(player, name)
	name = SaveData.cleanName(name)
	if sessionOnly then return name end
	local filtered = TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
	return SaveData.cleanName(filtered)
end

local function readSave(owner, slot, discovering)
	assert(SaveData.validOwner(owner) and SaveData.validSlot(slot), "Choose a valid save slot.")
	local key = SaveData.key(owner, slot)
	local raw = if discovering then discoveryRead(key, 15) else store:GetAsync(key)
	return if raw then BoatData.decode(raw) else nil
end

local function readOwnedSave(player, slot)
	local key = SaveData.key(player.UserId, slot)
	local raw = store:GetAsync(key)
	if raw == nil then return nil end
	local loaded = BoatData.decode(raw)
	if raw.SaveInfo ~= nil then
		SaveData.info(raw, player.UserId, slot)
		return loaded
	end
	local now, serverId = os.time(), HttpService:GenerateGUID(false)
	local saved = store:UpdateAsync(key, function(current)
		assert(type(current) == "table", "Your existing plot is unavailable. Please retry.")
		-- Validate the latest record, but attach metadata to its original fields.
		-- Registering a plot must not rewrite furniture or construction layouts.
		BoatData.decode(current)
		if current.SaveInfo ~= nil then
			SaveData.info(current, player.UserId, slot)
			return current
		end
		local preserved = table.clone(current)
		local info = SaveData.createInfo(player.UserId, slot, "Existing plot", false, now, serverId)
		info.MemberNames[tostring(player.UserId)] = player.Name
		preserved.SaveInfo = SaveData.touch(info, now)
		return preserved
	end)
	assert(type(saved) == "table", "Your existing plot could not be registered. Please retry.")
	return BoatData.decode(saved)
end

local function rememberJoined(player, owner, slot, remove)
	store:UpdateAsync(directoryKey(player.UserId), function(raw)
		local index = directory(raw)
		local id = SaveData.id(owner, slot)
		if remove then
			index.Joined[id] = nil
		else
			local count = 0
			for _ in index.Joined do count += 1 end
			assert(index.Joined[id] or count < 100, "Leave an old company before joining another.")
			index.Joined[id] = { OwnerUserId = owner, Slot = slot }
		end
		return index
	end)
	discoveryCache[directoryKey(player.UserId)] = nil
end

local function scanFriends(player, cache)
	if cache.scanning or os.clock() < (cache.nextScan or 0) then return end
	cache.scanning, cache.nextScan = true, os.clock() + 120
	task.spawn(function()
		local found = {}
		local ok, problem = pcall(function()
			local index = directory(discoveryRead(directoryKey(player.UserId), 30))
			-- Memberships are pointers in this sidebar, never the member's save slots.
			for id, pointer in index.Joined do
				if caches[player] ~= cache or player:GetAttribute("BoatDataStatus") == "Ready" then return end
				local profile = readSave(pointer.OwnerUserId, pointer.Slot, true)
				if profile then
					local info = SaveData.info(profile, pointer.OwnerUserId, pointer.Slot)
					if info.Members[tostring(player.UserId)] and info.Multiplayer then
						local entry = summary(profile, pointer.OwnerUserId, pointer.Slot, false)
						entry.IsMember = true
						found[id] = entry
					end
				end
			end
			local pages = Players:GetFriendsAsync(player.UserId)
			while caches[player] == cache do
				for _, friend in pages:GetCurrentPage() do
					if caches[player] ~= cache or player:GetAttribute("BoatDataStatus") == "Ready" or pendingTeleports[player] then return end
					local success, friendIndex = pcall(function()
						return directory(discoveryRead(directoryKey(friend.Id), 120))
					end)
					if success then
						for slot, entry in friendIndex.Slots do
							if SaveData.validSlot(tonumber(slot)) and type(entry) == "table" and entry.Multiplayer then
								local id = SaveData.id(friend.Id, tonumber(slot))
								local candidate = table.clone(entry)
								candidate.IsMember = found[id] and found[id].IsMember == true
								candidate.OwnerName = candidate.OwnerName or friend.Username
								found[id] = candidate
							end
						end
					end
					cache.companies = table.clone(found)
					task.wait()
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
		end)
		if caches[player] == cache then
			cache.companies, cache.scanning = found, false
			cache.friendError = if ok then nil else "Some friends could not load. Discovery will retry."
			if not ok then
				cache.nextScan = os.clock() + 15
				warn("[Saves] Friend discovery failed: " .. tostring(problem))
			end
		end
	end)
end

local function list(player)
	local cache = caches[player]
	local slots, entries = {}, {}
	local profiles = eachSlot(function(slot) return readOwnedSave(player, slot) or false end)
	for slot = 1, SaveData.MAX_SLOTS do
		local profile = profiles[slot]
		if profile then
			local entry = summary(profile, player.UserId, slot, true)
			table.insert(slots, entry)
			entries[tostring(slot)] = summary(profile, player.UserId, slot, false)
		else
			table.insert(slots, { Exists = false, OwnerUserId = player.UserId, Slot = slot })
		end
	end
	-- Repair discovery after an interrupted create/settings/index request. In
	-- particular this advertises the saved plot registered in the original slot.
	-- The player's own cards never wait on this write.
	if os.clock() >= (cache.nextIndex or 0) then
		cache.nextIndex = os.clock() + 60
		task.spawn(function()
			local ok, problem = pcall(store.UpdateAsync, store, directoryKey(player.UserId), function(raw)
				local index = directory(raw)
				index.Slots = entries
				return index
			end)
			if ok then
				discoveryCache[directoryKey(player.UserId)] = nil
			else
				cache.nextIndex = 0
				warn("[Saves] Discovery index will repair: " .. tostring(problem))
			end
		end)
	end
	scanFriends(player, cache)
	local companies = {}
	for _, entry in cache.companies do table.insert(companies, entry) end
	table.sort(companies, function(a, b)
		return if a.Name == b.Name then SaveData.id(a.OwnerUserId, a.Slot) < SaveData.id(b.OwnerUserId, b.Slot) else a.Name < b.Name
	end)
	return { Ok = true, Slots = slots, Companies = companies, FriendsLoading = cache.scanning, Message = cache.friendError, SessionOnly = sessionOnly }
end

local function saveSettings(player, payload, creating)
	local slot = payload.Slot
	assert(SaveData.validSlot(slot), "Choose one of your three save slots.")
	assert(type(payload.Multiplayer) == "boolean", "Choose single player or multiplayer.")
	-- The company type is chosen once, when the save is created.
	local companyType = if creating then SaveData.cleanCompanyType(payload.Company) else nil
	local name = filterName(player, payload.Name)
	local icon = if payload.Icon == nil then nil else checkIcon(SaveData.cleanIcon(payload.Icon))
	local serverId = HttpService:GenerateGUID(false)
	local now = os.time()
	local saved = store:UpdateAsync(SaveData.key(player.UserId, slot), function(raw)
		assert(not creating or raw == nil, "That save slot is already occupied.")
		assert(creating or raw ~= nil, "Create this save first.")
		local profile = BoatData.decode(raw)
		local info = if creating then SaveData.createInfo(player.UserId, slot, name, payload.Multiplayer, now, serverId)
			else SaveData.info(profile, player.UserId, slot)
		if creating then
			if icon then info.Icon = icon end
			profile.Branches = { [companyType] = true }
		else
			SaveData.edit(info, player.UserId, name, payload.Multiplayer, payload.RemoveUserId, icon)
		end
		info.ServerId = info.ServerId or serverId
		info.MemberNames[tostring(player.UserId)] = player.Name
		SaveData.touch(info, now)
		profile.SaveInfo = info
		return profile
	end)
	assert(type(saved) == "table", "The save could not be confirmed. Please retry.")
	if callbacks then callbacks.apply(SaveData.key(player.UserId, slot), BoatData.decode(saved)) end
	local indexed, problem = pcall(indexSave, saved, player.UserId, slot)
	if not indexed then warn("[Saves] Discovery index will repair: " .. tostring(problem)) end
	caches[player].nextIndex = 0
	local listed, result = pcall(list, player)
	return if listed then result else { Ok = true, Message = "Saved. Refresh to reload your saves." }
end

local function enter(player, payload)
	player:SetAttribute("SaveSelectionError", nil)
	local owner, slot = payload.OwnerUserId, payload.Slot
	assert(SaveData.validOwner(owner) and SaveData.validSlot(slot), "Choose a valid save.")
	local isFriend = false
	-- Creators skip the read: the transaction below checks the save exists, and
	-- only guests need the roster before it to decide on a friendship check.
	if owner ~= player.UserId then
		local profile = readSave(owner, slot)
		assert(profile, "This save does not exist.")
		local info = SaveData.info(profile, owner, slot)
		if not info.Members[tostring(player.UserId)] then
			isFriend = if RunService:IsStudio() and owner < 0 and player.UserId < 0 then true else player:IsFriendsWithAsync(owner)
		end
	end
	local serverId = HttpService:GenerateGUID(false)
	local key = SaveData.key(owner, slot)
	local saved = store:UpdateAsync(key, function(raw)
		assert(raw ~= nil, "This save no longer exists.")
		local current = BoatData.decode(raw)
		local currentInfo = SaveData.info(current, owner, slot)
		SaveData.join(currentInfo, player.UserId, isFriend, player.Name)
		currentInfo.ServerId = currentInfo.ServerId or serverId
		SaveData.touch(currentInfo, os.time())
		current.SaveInfo = currentInfo
		return current
	end)
	assert(type(saved) == "table", "Joining could not be confirmed. Please retry.")
	local profile = RodSerials.migrate(store, key, BoatData.decode(saved))
	local info = SaveData.info(profile, owner, slot)
	if owner ~= player.UserId then rememberJoined(player, owner, slot, false) end
	-- Saves open while the harbour is still building. The DataStore work above
	-- overlaps that build; handing the profile over needs the wallet service.
	while not admitted[player] and player.Parent ~= nil do task.wait(0.1) end
	assert(player.Parent ~= nil and callbacks, "This session has ended.")
	callbacks.apply(key, profile)
	-- Discovery is retryable and only feeds friends' lists, so it never holds
	-- up entering; the membership/progress transaction above is final.
	task.spawn(function()
		local indexed, problem = pcall(indexSave, profile, owner, slot)
		if not indexed then warn("[Saves] Discovery index will repair: " .. tostring(problem)) end
	end)
	local expanded = info.PlotExpanded == true or info.Multiplayer == true
	if expanded and not RunService:IsStudio() and game.PrivateServerId ~= info.ServerId then
		local options = Instance.new("TeleportOptions")
		options.ReservedServerId = info.ServerId
		options:SetTeleportData({ FishingWatersSave = { OwnerUserId = owner, Slot = slot } })
		pendingTeleports[player] = true
		player:SetAttribute("SaveTeleporting", true)
		local ok, failure = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
		if not ok then
			pendingTeleports[player] = nil
			player:SetAttribute("SaveTeleporting", false)
			error("The company server could not be reached. Please try joining again.")
		end
		return { Ok = true, Entering = true }
	end
	-- A company server cannot also simulate another save's business. Route solo
	-- saves through a public server when leaving a company's reserved server.
	if not expanded and not RunService:IsStudio() and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ FishingWatersSave = { OwnerUserId = owner, Slot = slot } })
		pendingTeleports[player] = true
		player:SetAttribute("SaveTeleporting", true)
		local ok = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
		if not ok then
			pendingTeleports[player] = nil
			player:SetAttribute("SaveTeleporting", false)
			error("The save server could not be reached. Please try joining again.")
		end
		return { Ok = true, Entering = true }
	end
	if callbacks.beforeActivate then callbacks.beforeActivate(player, profile) end
	callbacks.activate(player, key, profile, owner, slot)
	return { Ok = true, Entering = true }
end

local function leave(player, payload)
	local owner, slot = payload.OwnerUserId, payload.Slot
	assert(SaveData.validOwner(owner) and SaveData.validSlot(slot), "Choose a valid company.")
	local saved = store:UpdateAsync(SaveData.key(owner, slot), function(raw)
		assert(raw ~= nil, "This company no longer exists.")
		local profile = BoatData.decode(raw)
		local info = SaveData.info(profile, owner, slot)
		SaveData.leave(info, player.UserId)
		SaveData.touch(info, os.time())
		profile.SaveInfo = info
		return profile
	end)
	assert(type(saved) == "table", "Leaving could not be confirmed. Please retry.")
	rememberJoined(player, owner, slot, true)
	if callbacks then callbacks.apply(SaveData.key(owner, slot), BoatData.decode(saved)) end
	indexSave(saved, owner, slot)
	caches[player].companies[SaveData.id(owner, slot)] = nil
	return list(player)
end

local function request(player, action, payload)
	if not store then return { Ok = false, Message = "Saved data is unavailable. Please rejoin to retry." } end
	if not caches[player] then return { Ok = false, Message = "Your saves are still loading. Please retry." } end
	if busy[player] or os.clock() - (lastRequest[player] or -10) < 0.5 then
		return { Ok = false, Message = "Please wait a moment." }
	end
	-- Changing a live profile would strand boats, carried fish and pending jobs.
	-- Selecting another save happens on the next join, before any gameplay starts.
	if player:GetAttribute("BoatDataStatus") == "Ready" then
		return { Ok = false, Message = "Rejoin to select or edit a save." }
	end
	if pendingTeleports[player] then return { Ok = false, Message = "Joining the company server…" } end
	busy[player], lastRequest[player] = true, os.clock()
	local ok, result = pcall(function()
		if action == "List" then return list(player) end
		assert(type(payload) == "table", "Choose a save first.")
		if action == "Create" then return saveSettings(player, payload, true) end
		if action == "Settings" then return saveSettings(player, payload, false) end
		-- A pick made while the harbour is still building waits inside enter().
		if action == "Select" then return enter(player, payload) end
		if action == "Leave" then return leave(player, payload) end
		error("Unknown save action.")
	end)
	busy[player] = nil
	if ok then return result end
	warn("[Saves] " .. tostring(result))
	-- Assertion messages are authored here or in SaveData. Avoid exposing backend
	-- errors/keys while still giving useful validation and capacity feedback.
	local message = tostring(result):match(":%d+: (.+)$") or "Your saves could not be loaded or changed. Please try again."
	if #message > 180 or message:find("\n") or message:find("API") or message:find("DataStore") then
		message = "Your saves could not be loaded or changed. Please try again."
	end
	return { Ok = false, Message = message }
end

-- The wallet service installs these once it starts. A player who joined before
-- that is prepared now; teleport arrivals select their pointed save.
local function admit(player)
	if admitted[player] or not callbacks or player.Parent == nil then return end
	admitted[player] = true
	caches[player] = caches[player] or { companies = {} }
	callbacks.prepare(player)
	-- Teleport data selects only a pointer; persisted friendship/roster and
	-- settings are checked again before the destination exposes any progress.
	local ok, joinData = pcall(player.GetJoinData, player)
	local pointer = ok and joinData.TeleportData and joinData.TeleportData.FishingWatersSave
	if type(pointer) == "table" then
		busy[player] = true
		task.spawn(function()
			local entered, problem = pcall(enter, player, pointer)
			busy[player] = nil
			if not entered then
				player:SetAttribute("SaveSelectionError", "This company could not be joined. Please choose a save or try again.")
				warn("[Saves] Arrival selection failed: " .. tostring(problem))
			end
		end)
	end
end

-- Opens the save remote at server boot, before the harbour is built, so the
-- selector lists saves within a second of joining instead of after the map.
function Service.open(walletStore, onlyThisSession)
	if opened then return end
	opened, store, sessionOnly = true, walletStore, onlyThisSession
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name, remotes.Parent = "Remotes", ReplicatedStorage
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name, remote.Parent = "SaveRequest", remotes
	remote.OnServerInvoke = request
	TeleportService.TeleportInitFailed:Connect(function(player)
		if pendingTeleports[player] then
			pendingTeleports[player] = nil
			player:SetAttribute("SaveTeleporting", false)
			player:SetAttribute("SaveSelectionError", "The company server could not be reached. Please try joining again.")
		end
	end)
	local function joined(player)
		caches[player] = caches[player] or { companies = {} }
		admit(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player)
		caches[player], busy[player], lastRequest[player], pendingTeleports[player], admitted[player] = nil, nil, nil, nil, nil
	end)
	for _, player in Players:GetPlayers() do task.spawn(joined, player) end
end

function Service.start(walletStore, onlyThisSession, handlers)
	if started then return end
	Service.open(walletStore, onlyThisSession)
	started, callbacks = true, handlers
	for _, player in Players:GetPlayers() do task.spawn(admit, player) end
end

return Service
